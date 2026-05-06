# frozen_string_literal: true

require_relative 'app'

module FinanceTracker
  # Wallet routes
  class Api < Roda
    route('wallets') do |routing|
      @wallet_route = "#{@api_root}/wallets"

      # GET api/v1/wallets/[wallet_id]
      routing.get String do |wallet_id|
        wallet = Wallet.first(id: wallet_id)
        wallet ? wallet.to_json : raise('Wallet not found')
      rescue StandardError => e
        routing.halt 404, { message: e.message }.to_json
      end

      # GET api/v1/wallets
      routing.get do
        { data: Wallet.all }.to_json
      rescue StandardError
        routing.halt 404, { message: 'Could not find wallets' }.to_json
      end

      # POST api/v1/wallets
      routing.post do
        new_data = JSON.parse(routing.body.read)
        new_wallet = Wallet.create(new_data)

        response.status = 201
        response['Location'] = "#{@wallet_route}/#{new_wallet.id}"
        { message: 'Wallet saved', data: new_wallet }.to_json
      rescue Sequel::MassAssignmentRestriction
        Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
        routing.halt 400, { message: 'Illegal Attributes' }.to_json
      rescue StandardError => e
        Api.logger.error "UNKNOWN ERROR: #{e.message}"
        routing.halt 500, { message: 'Unknown server error' }.to_json
      end
    end
  end
end
