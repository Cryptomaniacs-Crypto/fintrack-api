# frozen_string_literal: true

module FinanceTracker
  # Retrieves an account by username.
  class GetAccountByUsername
    class AccountNotFoundError < StandardError; end

    def self.call(username:)
      account = Account.first(username:)
      raise AccountNotFoundError, 'Account not found' unless account

      account
    end
  end
end
