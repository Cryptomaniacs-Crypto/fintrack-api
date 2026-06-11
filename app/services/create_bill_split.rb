# frozen_string_literal: true

module FinanceTracker
  # Creates a draft bill split from a title plus a list of participant
  # usernames. The creator is always included as a participant (they usually
  # ate too); items and tax/service are added later via UpdateBillSplit.
  class CreateBillSplit
    class InvalidInput < StandardError; end
    class UnknownParticipant < StandardError; end

    def self.call(creator:, title:, participant_usernames:, note: nil)
      title = title.to_s.strip
      raise InvalidInput, 'Title is required' if title.empty?

      accounts = resolve_accounts(creator, participant_usernames)
      raise InvalidInput, 'Add at least one other participant' if accounts.size < 2

      FinanceTracker::Api.DB.transaction do
        bill = BillSplit.new(creator_id: creator.id, title:)
        bill.note = note if note
        bill.save_changes
        accounts.each { |account| BillSplitParticipant.create(bill_split_id: bill.id, account_id: account.id) }
        bill.reload
      end
    end

    # Creator first, then the named participants (deduped), each resolved to an
    # account or rejected as unknown.
    def self.resolve_accounts(creator, participant_usernames)
      usernames = Array(participant_usernames).map { |name| name.to_s.strip }.reject(&:empty?)
      usernames = ([creator.username] + usernames).uniq

      usernames.map do |username|
        Account.first(username:) or raise UnknownParticipant, "Unknown user: #{username}"
      end
    end
  end
end
