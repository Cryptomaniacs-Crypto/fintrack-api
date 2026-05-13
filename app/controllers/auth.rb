# frozen_string_literal: true

require_relative 'app'

module FinanceTracker
  # Authentication routes
  class Api < Roda
    route('auth') do |routing|
      routing.is 'authentication' do
        # POST api/v1/auth/authentication
        routing.post do
          credentials = JSON.parse(routing.body.read, symbolize_names: true)
          auth_account = AuthenticateAccount.call(credentials)
          auth_account.to_json
        rescue AuthenticateAccount::UnauthorizedError => e
          Api.logger.warn "AUTH FAILED: #{e.message}"
          routing.halt 403, { message: 'Invalid credentials' }.to_json
        rescue StandardError => e
          Api.logger.error "UNKNOWN ERROR: #{e.message}"
          routing.halt 500, { message: 'Unknown server error' }.to_json
        end
      end
    end
  end
end
