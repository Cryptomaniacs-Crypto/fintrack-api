# frozen_string_literal: true

module FinanceTracker
  class WalletScope
    def initialize(account)
      @account = account
    end

    # Wallets are private financial data: every account — admins included —
    # sees only its own. Admin power is for managing accounts/roles, not for
    # reading other users' balances.
    def viewable
      return Wallet.where(Sequel.lit('1 = 0')) unless @account

      Wallet.where(account_id: @account.id)
    end
  end
end
