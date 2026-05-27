# frozen_string_literal: true

module FinanceTracker
  class WalletScope
    def initialize(account)
      @account = account
    end

    def viewable
      return Wallet.where(Sequel.lit('1 = 0')) unless @account
      return Wallet.all if AccountPolicy.new(@account).is_admin?

      Wallet.where(account_id: @account.id)
    end
  end
end
