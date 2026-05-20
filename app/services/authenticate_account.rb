<<<<<<< HEAD
# frozen_string_literal: true

require 'json'

module FinanceTracker
  # Find account, check password, and issue an encrypted auth token.
  class AuthenticateAccount
    # Raised when credentials do not match a known account.
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

      account_envelope = JSON.parse(account.to_json)
      {
        type: 'authenticated_account',
        attributes: {
          account: account_envelope,
          auth_token: token_for(account_envelope, account.id)
        }
      }
    end

    # Encrypted token carries the account envelope plus the internal `id`
    # the API needs for inline role checks. The id stays out of the
    # plaintext response -- only callers with MSG_KEY can read it back.
    def self.token_for(envelope, account_id)
      token_envelope = envelope.merge(
        'attributes' => envelope['attributes'].merge('id' => account_id)
      )
      AuthToken.new(token_envelope).to_s
    end
  end
end
=======
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
>>>>>>> 8e8e0ae15e4c4c7912a868ad23881cff84c9cfe7
