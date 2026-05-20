# frozen_string_literal: true

require_relative 'app'
require_relative '../services/verify_registration'

module FinanceTracker
  # Authentication routes
  class Api < Roda
    route('auth') do |routing|
      routing.is 'authentication' do
        # POST api/v1/auth/authentication
        routing.post do
          credentials = JSON.parse(routing.body.read, symbolize_names: true)
          AuthenticateAccount.call(credentials).to_json
        rescue AuthenticateAccount::UnauthorizedError => e
          Api.logger.warn "AUTH FAILED: #{e.message}"
          routing.halt 403, { message: 'Invalid credentials' }.to_json
        rescue StandardError => e
          Api.logger.error "UNKNOWN ERROR: #{e.message}"
          routing.halt 500, { message: 'Unknown server error' }.to_json
        end
      end

      routing.is 'register' do
        # POST api/v1/auth/register
        routing.post do
          registration = JSON.parse(routing.body.read, symbolize_names: true)
          VerifyRegistration.new(registration).call
          { message: 'Verification email sent' }.to_json
        rescue VerifyRegistration::InvalidRegistration => e
          routing.halt 400, { message: e.message }.to_json
        rescue VerifyRegistration::EmailProviderError => e
          Api.logger.error "EMAIL PROVIDER ERROR: #{e.message}"
          routing.halt 502, { message: e.message }.to_json
        rescue StandardError => e
          Api.logger.error "UNKNOWN ERROR: #{e.message}"
          routing.halt 500, { message: 'Unknown server error' }.to_json
        end
      end
    end
  end
end
