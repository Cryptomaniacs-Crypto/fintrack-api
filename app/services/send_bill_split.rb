# frozen_string_literal: true

require 'date'

module FinanceTracker
  # Sends a draft to participants. When the owner names a wallet, records their
  # upfront expense for the grand total (they fronted the bill). The owner's own
  # participant row is auto-settled — they don't repay themselves.
  class SendBillSplit
    class InvalidInput < StandardError; end

    def self.call(bill:, owner:, wallet_id: nil)
      raise InvalidInput, 'Add at least one dish before sending' if bill.items.empty?
      raise InvalidInput, 'Bill split is already settled' if bill.settled?

      FinanceTracker::Api.DB.transaction do
        record_outlay(bill, owner, wallet_id) unless wallet_id.to_s.empty?
        bill.send!
        bill.participant_for(owner)&.settle!
        bill.reload
      end
    end

    def self.record_outlay(bill, owner, wallet_id)
      wallet = WalletOwnership.owned!(owner, wallet_id, InvalidInput)
      tx = FinanceTracker::Transaction.create(
        title: "Bill split: #{bill.title} (you fronted)",
        amount: "-#{bill.grand_total}",
        transaction_date: Date.today,
        wallet_id: wallet.id
      )
      bill.creator_wallet_id = wallet.id
      bill.outlay_transaction_id = tx.id
      bill.save_changes
    end
  end

  # Shared wallet-ownership guard for the settlement services.
  module WalletOwnership
    module_function

    def owned!(account, wallet_id, error_class)
      wallet = FinanceTracker::Wallet.first(id: wallet_id)
      raise error_class, 'Wallet not found' unless wallet
      raise error_class, 'That wallet does not belong to you' unless wallet.account_id == account.id

      wallet
    end
  end
end
