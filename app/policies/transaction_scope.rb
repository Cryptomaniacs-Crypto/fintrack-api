# frozen_string_literal: true

module FinanceTracker
  class TransactionScope
    def initialize(account)
      @account = account
    end

    def viewable
      return Transaction.where(Sequel.lit('1 = 0')) unless @account
      return Transaction.all if AccountPolicy.new(@account).is_admin?

      wallet_ids = Wallet.where(account_id: @account.id).select(:id)
      Transaction.where(wallet_id: wallet_ids)
    end
  end
end
