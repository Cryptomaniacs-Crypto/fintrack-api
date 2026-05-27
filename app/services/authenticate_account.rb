# frozen_string_literal: true

module FinanceTracker
  # Looks up an account by username and verifies its password.
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end

    def self.call(username:, password:)
      raise UnauthorizedError, 'Username and password required' if username.to_s.empty? || password.to_s.empty?

      account = Account.first(username: username)
      raise UnauthorizedError, 'Invalid credentials' unless account&.password?(password)

      account
    end
  end
end
