# frozen_string_literal: true

module FinanceTracker
  # Verifies a username/password pair and returns the account on success.
  class AuthenticateAccount
    # Raised when username/password do not match a known account.
    class UnauthorizedError < StandardError
      def initialize(credentials)
        @credentials = credentials
        super
      end

      def message
        "Invalid credentials for: #{@credentials[:username]}"
      end
    end

    def self.call(credentials)
      account = Account.first(username: credentials[:username])
      raise UnauthorizedError, credentials unless
        account&.password?(credentials[:password])

      account
    end
  end
end
