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

    # Token payload carries the account_id (used by Api.authorize! to
    # identify the requesting account) and username (handy for logs).
    # The envelope's attributes live at envelope['data']['attributes'],
    # not envelope['attributes'] -- the previous merge crashed on nil.
    def self.token_for(envelope, account_id)
      payload = {
        'account_id' => account_id,
        'username' => envelope.dig('data', 'attributes', 'username')
      }
      AuthToken.new(payload).to_s
    end
  end
end
