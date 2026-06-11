# frozen_string_literal: true

module FinanceTracker
  class TransactionScope
    def initialize(account)
      @account = account
    end

    # Transactions are private financial data: every account — admins included —
    # sees only its own. Admin power is for managing accounts/roles, not for
    # reading other users' spending.
    def viewable
      return Transaction.where(Sequel.lit('1 = 0')) unless @account

      wallet_ids = Wallet.where(account_id: @account.id).select(:id)
      Transaction.where(wallet_id: wallet_ids)
    end
  end
end
