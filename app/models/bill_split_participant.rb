# frozen_string_literal: true

require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # One account's membership in a bill split. Carries that person's agreement
  # state and (when they reject) an encrypted reason note.
  class BillSplitParticipant < Sequel::Model
    many_to_one :bill_split, class: :'FinanceTracker::BillSplit'
    many_to_one :account, class: :'FinanceTracker::Account'
    many_to_many :items,
                 class: :'FinanceTracker::BillSplitItem',
                 join_table: :bill_split_item_shares,
                 left_key: :bill_split_participant_id,
                 right_key: :bill_split_item_id

    plugin :uuid, field: :id
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :bill_split_id, :account_id

    # reject_note is sensitive: stored encrypted, exposed as a plaintext virtual.
    def reject_note
      SecureDB.decrypt(reject_note_secure)
    end

    def reject_note=(plaintext)
      stripped = plaintext.to_s.strip
      self.reject_note_secure = stripped.empty? ? nil : SecureDB.encrypt(stripped)
    end

    # Status predicates
    def pending?  = status == 'pending'
    def agreed?   = status == 'agreed'
    def rejected? = status == 'rejected'
    def settled?  = status == 'settled'

    # State columns are whitelist-restricted from mass assignment, so these
    # transitions set them through individual setters rather than update(hash).
    def agree!
      self.status = 'agreed'
      self.agreed_at = Time.now.utc
      self.reject_note_secure = nil
      self.rejected_at = nil
      save_changes
      self
    end

    def reject!(reason)
      raise 'Reject reason is required' if reason.to_s.strip.empty?

      self.reject_note = reason
      self.status = 'rejected'
      self.rejected_at = Time.now.utc
      save_changes
      self
    end

    # Reset to pending so the participant re-reviews after an owner edit.
    def reset!
      self.status = 'pending'
      self.agreed_at = nil
      self.rejected_at = nil
      self.reject_note_secure = nil
      save_changes
      self
    end

    def settle!
      self.status = 'settled'
      self.settled_at = Time.now.utc
      save_changes
      self
    end
  end
end
