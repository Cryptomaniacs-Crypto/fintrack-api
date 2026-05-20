# frozen_string_literal: true

module FinanceTracker
  # Lists payment methods owned by the current account.
  class ListPaymentMethodsForAccount
    class UnknownCurrentAccountError < StandardError; end

    def self.call(current_account_id:)
      account = Account.first(id: current_account_id)
      raise UnknownCurrentAccountError, 'Account not found' unless account

      Wallet.where(account_id: account.id).all
    end
  end
end
