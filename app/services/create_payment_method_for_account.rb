# frozen_string_literal: true

module FinanceTracker
  # Creates a payment method scoped to the current account.
  class CreatePaymentMethodForAccount
    class UnknownCurrentAccountError < StandardError; end
    class InvalidMethodTypeError < StandardError; end

    def self.call(current_account_id:, payment_method_data:)
      account = Account.first(id: current_account_id)
      raise UnknownCurrentAccountError, 'Account not found' unless account

      method_type = payment_method_data[:method_type].to_s.strip
      method_type = 'cash' if method_type.empty?
      raise InvalidMethodTypeError, 'Unknown payment method type' unless Wallet::METHOD_TYPES.include?(method_type)

      Wallet.create(payment_method_data.merge(account_id: account.id, method_type: method_type))
    end
  end
end
