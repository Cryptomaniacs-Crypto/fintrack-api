# frozen_string_literal: true

require 'bigdecimal'
require 'json'
require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # An itemized, multi-person bill split owned by `creator`. Holds many
  # participants and many dishes (items); each dish is split equally among the
  # participants who shared it, then bill-wide tax/service percentages are
  # applied proportionally to each person's subtotal.
  #
  # Lifecycle: draft -> pending (sent to participants) -> disputed (someone
  # rejected) -> settled. Owner edits are allowed only while editable? (draft or
  # disputed) and reset every participant back to pending.
  class BillSplit < Sequel::Model
    many_to_one :creator, class: :'FinanceTracker::Account', key: :creator_id
    many_to_one :category, class: :'FinanceTracker::Category', key: :category_id
    one_to_many :participants, class: :'FinanceTracker::BillSplitParticipant', key: :bill_split_id
    one_to_many :items, class: :'FinanceTracker::BillSplitItem', key: :bill_split_id

    plugin :uuid, field: :id
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :creator_id, :title, :tax_percent, :service_percent, :category_id

    # note is an optional sensitive free-text field, encrypted at rest.
    def note
      SecureDB.decrypt(note_secure)
    end

    def note=(plaintext)
      stripped = plaintext.to_s.strip
      self.note_secure = stripped.empty? ? nil : SecureDB.encrypt(stripped)
    end

    # Status predicates
    def draft?    = status == 'draft'
    def pending?  = status == 'pending'
    def disputed? = status == 'disputed'
    def settled?  = status == 'settled'

    # Editing is allowed only before settlement AND before any money has moved
    # (no non-owner participant has paid or settled). Once payments start, the
    # amounts are locked.
    def editable? = (draft? || disputed?) && !payments_started?

    # Has any non-owner participant paid or settled their share?
    def payments_started?
      participants.any? { |p| p.account_id != creator_id && (p.paid? || p.settled?) }
    end

    # Participants who actually owe the owner (everyone but the owner).
    def non_creator_participants
      participants.reject { |p| p.account_id == creator_id }
    end

    # Authorization helpers
    def creator?(account)
      account&.id == creator_id
    end

    def participant_for(account)
      participants.find { |p| p.account_id == account&.id }
    end

    def participant?(account)
      creator?(account) || !participant_for(account).nil?
    end

    # Send the bill to participants. Requires at least one dish.
    # (Status columns are whitelist-restricted, so set via individual setters.)
    def send!
      raise 'Add at least one dish before sending' if items.empty?
      raise 'Bill split is already settled' if settled?

      self.status = 'pending'
      self.sent_at ||= Time.now.utc
      save_changes
      self
    end

    # An owner edit moves a disputed/pending bill back to a clean pending review.
    def reset_participants!
      participants.each(&:reset!)
      self
    end

    # A participant rejection pushes the whole bill into the disputed state so
    # the owner can revise it.
    def mark_disputed!
      return self if settled?

      self.status = 'disputed'
      save_changes
      self
    end

    # This participant's computed total (money string), from the breakdown.
    def total_for(participant)
      row = breakdown.find { |r| r[:participant_id] == participant.id }
      row ? row[:total] : '0.0'
    end

    # Reverse the owner's upfront expense (used when an edit revises amounts).
    def clear_outlay!
      FinanceTracker::Transaction.where(id: outlay_transaction_id).delete if outlay_transaction_id
      self.creator_wallet_id = nil
      self.outlay_transaction_id = nil
      save_changes
      self
    end

    # Deleting a bill also removes every wallet transaction it created, so the
    # money it generated is reversed rather than orphaned.
    def before_destroy
      ids = participants.flat_map { |p| [p.expense_transaction_id, p.income_transaction_id] }
      ids << outlay_transaction_id
      FinanceTracker::Transaction.where(id: ids.compact).delete unless ids.compact.empty?
      super
    end

    # Mark the whole bill settled once every owing participant has settled.
    def settle_if_complete!
      return self if settled?
      return self unless non_creator_participants.all?(&:settled?)

      self.status = 'settled'
      self.settled_at = Time.now.utc
      save_changes
      self
    end

    # Per-participant money breakdown. Rounds once per person at the end.
    def breakdown
      tax = to_decimal(tax_percent)
      service = to_decimal(service_percent)

      participants.map do |participant|
        subtotal = participant.items.sum(BigDecimal('0'), &:share_amount)
        tax_amount = (subtotal * tax / 100).round(2)
        service_amount = (subtotal * service / 100).round(2)
        {
          participant_id: participant.id,
          account_id: participant.account_id,
          username: participant.account&.username,
          status: participant.status,
          reject_note: participant.reject_note,
          subtotal: money(subtotal),
          tax: money(tax_amount),
          service: money(service_amount),
          total: money(subtotal + tax_amount + service_amount),
          is_owner: participant.account_id == creator_id,
          paid_at: participant.paid_at,
          has_proof: participant.proof?
        }
      end
    end

    def grand_total
      # Compute from raw item amounts so rounding in per-person shares never
      # causes the total to drift (e.g. $10 split 3 ways rounds to $3.33×3=$9.99).
      raw = items.sum(BigDecimal('0')) { |item| BigDecimal(item.amount.to_s) }
      tax     = to_decimal(tax_percent)
      service = to_decimal(service_percent)
      money(raw + raw * tax / 100 + raw * service / 100)
    end

    def to_h
      {
        id:,
        title:,
        note:,
        tax_percent:,
        service_percent:,
        category_id:,
        category_name: category&.name,
        status:,
        creator_id:,
        creator_username: creator&.username,
        creator_wallet_id:,
        grand_total:,
        sent_at:,
        settled_at:,
        created_at:,
        updated_at:,
        participants: breakdown,
        items: items.map do |item|
          {
            id: item.id,
            name: item.name,
            amount: item.amount,
            sharer_participant_ids: item.participants.map(&:id),
            sharer_usernames: item.participants.map { |p| p.account&.username }
          }
        end
      }
    end

    def to_json(options = {})
      JSON({ data: { type: 'bill_split', attributes: to_h } }, options)
    end

    # Viewer-scoped serialization (least privilege):
    # - the creator sees the full breakdown (everyone's shares + who shared what)
    # - a non-owner participant sees ONLY their own share, itemized so they can
    #   verify it, plus the bill total and headcount — but never another person's
    #   amounts or identities, and not the owner's private note.
    def to_h_for(viewer)
      return to_h if creator?(viewer)

      participant = participant_for(viewer)
      return to_h unless participant # route already guards non-participants

      participant_view(participant)
    end

    def to_json_for(viewer, options = {})
      JSON({ data: { type: 'bill_split', attributes: to_h_for(viewer) } }, options)
    end

    # Each item the participant shares: full price, how many people split it
    # (count only — not who), and this participant's portion. Enough to recompute
    # their own number without exposing anyone else.
    def itemized_share_for(participant)
      items.select { |item| item.participants.any? { |p| p.id == participant.id } }
           .map do |item|
        count = item.participants.count
        share = count.zero? ? BigDecimal('0') : BigDecimal(item.amount.to_s) / count
        {
          id: item.id,
          name: item.name,
          amount: item.amount,
          shared_by_count: count,
          your_share: money(share)
        }
      end
    end

    def participant_view(participant)
      row = breakdown.find { |r| r[:participant_id] == participant.id }
      {
        id:,
        title:,
        tax_percent:,
        service_percent:,
        category_id:,
        category_name: category&.name,
        status:,
        creator_id:,
        creator_username: creator&.username,
        grand_total:,
        participant_count: participants.count,
        viewer_is_owner: false,
        sent_at:,
        settled_at:,
        created_at:,
        updated_at:,
        participants: row ? [row] : [],
        items: itemized_share_for(participant)
      }
    end

    private

    def to_decimal(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal('0')
    end

    def money(value)
      value.round(2).to_s('F')
    end
  end
end
