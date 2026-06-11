# frozen_string_literal: true

require 'date'
require 'bigdecimal'

module FinanceTracker
  # Sends a draft to participants. When the owner names a wallet:
  #   - Records their personal share as an expense ("your share").
  #   - Records the amount fronted on behalf of others as a separate expense
  #     ("you fronted"), so income from each participant's repayment offsets
  #     only that portion.
  # The owner's own participant row is auto-settled — they don't repay themselves.
  class SendBillSplit
    class InvalidInput < StandardError; end

    def self.call(bill:, owner:, wallet_id: nil)
      raise InvalidInput, 'Add at least one dish before sending' if bill.items.empty?
      raise InvalidInput, 'Bill split is already settled' if bill.settled?

      FinanceTracker::Api.DB.transaction do
        unless wallet_id.to_s.empty?
          wallet            = WalletOwnership.owned!(owner, wallet_id, InvalidInput)
          owner_participant = bill.participant_for(owner)
          owner_share       = owner_participant ? BigDecimal(bill.total_for(owner_participant)) : BigDecimal('0')

          record_outlay(bill, wallet, owner_share)
          record_owner_share(bill, wallet, owner_participant, owner_share) if owner_share > 0
        end
        bill.send!
        bill.participant_for(owner)&.settle!
        bill.reload
      end
    end

    # Records only what the owner fronted on behalf of others (grand_total minus
    # the owner's own share). Repayments from each participant come back as income
    # against this amount.
    def self.record_outlay(bill, wallet, owner_share)
      others_total = (BigDecimal(bill.grand_total) - owner_share).round(2)
      bill.creator_wallet_id = wallet.id
      if others_total > 0
        tx = FinanceTracker::Transaction.create(
          title: "Bill split: #{bill.title} (you fronted)",
          amount: "-#{others_total}",
          transaction_date: Date.today,
          wallet_id: wallet.id,
          category_id: bill.category_id
        )
        bill.outlay_transaction_id = tx.id
      end
      bill.save_changes
    end

    # Records the owner's own portion as a regular expense, mirroring what other
    # participants record when they pay.
    def self.record_owner_share(bill, wallet, owner_participant, owner_share)
      tx = FinanceTracker::Transaction.create(
        title: "Bill split: #{bill.title} (your share)",
        amount: "-#{owner_share}",
        transaction_date: Date.today,
        wallet_id: wallet.id,
        category_id: bill.category_id
      )
      owner_participant.expense_transaction_id = tx.id
      owner_participant.paid_wallet_id         = wallet.id
      owner_participant.save_changes
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
