# frozen_string_literal: true

module FinanceTracker
  # Fetches one payment method scoped to the current account.
  class GetPaymentMethodForAccount
    class UnknownCurrentAccountError < StandardError; end
    class UnknownPaymentMethodError < StandardError; end

    def self.call(current_account_id:, payment_method_id:)
      account = Account.first(id: current_account_id)
      raise UnknownCurrentAccountError, 'Account not found' unless account

      payment_method = Wallet.first(id: payment_method_id, account_id: account.id)
      raise UnknownPaymentMethodError, 'Payment method not found' unless payment_method

      payment_method
    end
  end
end
