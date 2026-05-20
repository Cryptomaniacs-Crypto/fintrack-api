# frozen_string_literal: true

module FinanceTracker
  # Lists transactions owned by the current account
  # by joining through their wallets.
  class ListTransactionsForAccount
    class UnknownCurrentAccountError < StandardError; end

    def self.call(current_account_id:)
      account = Account.first(id: current_account_id)
      raise UnknownCurrentAccountError, 'Account not found' unless account

      wallet_ids = account.wallets.map(&:id)
      return [] if wallet_ids.empty?

      Transaction.where(wallet_id: wallet_ids).all
    end
  end
end
