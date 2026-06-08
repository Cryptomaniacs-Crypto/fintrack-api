# frozen_string_literal: true

module FinanceTracker
  # Replaces a draft/disputed bill's dishes and bill-wide tax/service, then
  # resets every participant back to pending so they re-review the revised
  # amounts. Items are replaced wholesale: each dish carries a name, an amount,
  # and the set of participants who share it (matched by username or
  # participant id within this bill).
  class UpdateBillSplit
    class InvalidInput < StandardError; end
    class NotEditable < StandardError; end

    def self.call(bill_split:, title: nil, tax_percent: nil, service_percent: nil, note: nil, items: nil)
      raise NotEditable, 'This bill can no longer be edited' unless bill_split.editable?

      FinanceTracker::Api.DB.transaction do
        # Editing a previously-sent (now disputed) bill revises amounts, so undo
        # the owner's upfront expense and drop it back to draft for a fresh send.
        bill_split.clear_outlay! if bill_split.outlay_transaction_id
        apply_attributes(bill_split, title, tax_percent, service_percent, note)
        replace_items(bill_split, items) unless items.nil?
        bill_split.reset_participants!
        revert_to_draft(bill_split)
        bill_split.reload
      end
    end

    # A revised bill must be re-sent, so it returns to draft and clears sent_at.
    def self.revert_to_draft(bill)
      return if bill.status == 'draft'

      bill.status = 'draft'
      bill.sent_at = nil
      bill.save_changes
    end

    def self.apply_attributes(bill, title, tax_percent, service_percent, note)
      cleaned_title = title.to_s.strip
      bill.title = cleaned_title unless cleaned_title.empty?
      bill.tax_percent = normalize_percent(tax_percent) unless tax_percent.nil?
      bill.service_percent = normalize_percent(service_percent) unless service_percent.nil?
      bill.note = note unless note.nil?
      bill.save_changes
    end

    def self.replace_items(bill, items)
      by_username = bill.participants.to_h { |p| [p.account&.username, p] }
      by_id = bill.participants.to_h { |p| [p.id, p] }

      bill.items.each(&:destroy) # cascade removes the share rows
      Array(items).each do |item|
        name = (item[:name] || item['name']).to_s.strip
        next if name.empty?

        record = BillSplitItem.create(bill_split_id: bill.id, name:, amount: normalize_amount(item[:amount] || item['amount']))
        sharers = resolve_sharers(item, by_username, by_id)
        raise InvalidInput, "Dish '#{name}' needs at least one person sharing it" if sharers.empty?

        sharers.each { |participant| record.add_participant(participant) }
      end
    end

    # Sharers may be given as participant ids or usernames; both are matched
    # against this bill's participants only.
    def self.resolve_sharers(item, by_username, by_id)
      ids = Array(item[:sharer_participant_ids] || item['sharer_participant_ids'])
      names = Array(item[:sharer_usernames] || item['sharer_usernames'])
      (ids.map { |id| by_id[id] } + names.map { |name| by_username[name.to_s] }).compact.uniq
    end

    def self.normalize_percent(value)
      raw = value.to_s.strip
      raw = '0' if raw.empty?
      parsed = Float(raw, exception: false)
      raise InvalidInput, 'Tax/service must be zero or a positive number' if parsed.nil? || parsed.negative?

      raw
    end

    def self.normalize_amount(value)
      raw = value.to_s.strip
      parsed = Float(raw, exception: false)
      raise InvalidInput, 'Each dish needs a positive amount' if parsed.nil? || parsed <= 0

      raw
    end
  end
end
