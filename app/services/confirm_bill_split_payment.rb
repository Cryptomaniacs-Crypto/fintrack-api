# frozen_string_literal: true

require 'date'

module FinanceTracker
  # The owner confirms receipt of a participant's payment: records an income on
  # one of the OWNER's wallets and settles that participant. The whole bill
  # settles once every owing participant is settled.
  class ConfirmBillSplitPayment
    class InvalidInput < StandardError; end
    class NotAllowed < StandardError; end

    def self.call(bill:, owner:, participant:, wallet_id:)
      raise NotAllowed, 'Only the owner can confirm payments' unless bill.creator?(owner)
      raise InvalidInput, 'This participant has not paid yet' unless participant.paid?

      wallet = WalletOwnership.owned!(owner, wallet_id, InvalidInput)

      FinanceTracker::Api.DB.transaction do
        tx = FinanceTracker::Transaction.create(
          title: "Bill split: #{bill.title} (#{participant.account&.username}'s share)",
          amount: bill.total_for(participant),
          transaction_date: Date.today,
          wallet_id: wallet.id,
          category_id: bill.category_id
        )
        participant.status = 'settled'
        participant.received_wallet_id = wallet.id
        participant.income_transaction_id = tx.id
        participant.settled_at = Time.now.utc
        participant.save_changes
        bill.reload.settle_if_complete!
        bill.reload
      end
    end
  end
end
