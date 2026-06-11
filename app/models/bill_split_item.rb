# frozen_string_literal: true

require 'bigdecimal'
require 'json'
require 'sequel'

module FinanceTracker
  # A single dish/line on a bill split, shared equally among the participants
  # linked through bill_split_item_shares.
  class BillSplitItem < Sequel::Model
    many_to_one :bill_split, class: :'FinanceTracker::BillSplit'
    many_to_many :participants,
                 class: :'FinanceTracker::BillSplitParticipant',
                 join_table: :bill_split_item_shares,
                 left_key: :bill_split_item_id,
                 right_key: :bill_split_participant_id

    plugin :uuid, field: :id
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :bill_split_id, :name, :amount

    # Each sharer owes an equal slice of the dish. Unrounded on purpose:
    # rounding happens once per person in BillSplit#breakdown so cents don't
    # leak away mid-sum.
    def share_amount
      count = participants.count
      return BigDecimal('0') if count.zero?

      BigDecimal(amount.to_s) / count
    end
  end
end
