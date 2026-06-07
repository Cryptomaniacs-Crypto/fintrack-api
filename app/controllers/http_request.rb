# frozen_string_literal: true

require 'json'

require_relative '../lib/auth_token'
require_relative '../lib/signed_request'
require_relative '../models/authorized_account'

module FinanceTracker
  # Small request wrapper for JSON bodies and bearer tokens.
  class HttpRequest
    def initialize(routing)
      @routing = routing
    end

    def body_data
      @body_data ||= begin
        raw = @routing.body&.read.to_s
        raw.empty? ? {} : JSON.parse(raw, symbolize_names: true)
      end
    end

    # Verifies the request signature and returns the inner data (symbol-keyed),
    # or raises SignedRequest::VerificationError. Used for POSTs that carry no
    # auth_token (login, register, SSO), which must be signed by the app.
    def signed_body_data
      SignedRequest.parse(body_data)
    end

    def auth_token
      auth_header = @routing.env['HTTP_AUTHORIZATION']
      return nil unless auth_header

      auth_header[/\ABearer\s+(.+)\z/i, 1]
    end

    # Decrypts the Bearer token into an AuthorizedAccount carrying the account
    # identity payload plus the token's AuthScope, or nil when no token is
    # present. Raises AuthToken::InvalidTokenError / ExpiredTokenError when a
    # token is present but unparseable or expired -- the controller maps those
    # to 401 so a bad token never silently degrades to anonymous access.
    def authorized_account
      token = auth_token
      return nil unless token

      decoded = AuthToken.load(token)
      AuthorizedAccount.new(decoded.payload, decoded.scope)
    end

    def secure?
      raise 'Secure scheme not configured' unless Api.config.SECURE_SCHEME

      @routing.scheme.casecmp(Api.config.SECURE_SCHEME).zero?
    end
  end
end
