# frozen_string_literal: true

require_relative 'app'
require_relative 'http_request'
require_relative '../services/create_payment_method_for_account'
require_relative '../services/list_payment_methods_for_account'
require_relative '../services/get_payment_method_for_account'

module FinanceTracker
  # Payment method routes backed by wallets.
  class Api < Roda
    route('wallets') do |routing|
      @wallet_route = "#{@api_root}/wallets"

      # GET api/v1/wallets/[wallet_id]
      routing.get String do |wallet_id|
        current_account_id = routing.params['current_account_id']
        routing.halt 401, { message: 'Missing current_account_id' }.to_json unless current_account_id

        wallet = GetPaymentMethodForAccount.call(
          current_account_id: current_account_id,
          payment_method_id: wallet_id
        )
        wallet.to_json
      rescue GetPaymentMethodForAccount::UnknownCurrentAccountError => e
        routing.halt 404, { message: e.message }.to_json
      rescue GetPaymentMethodForAccount::UnknownPaymentMethodError => e
        routing.halt 404, { message: e.message }.to_json
      rescue StandardError => e
        Api.logger.error "UNKNOWN ERROR: #{e.message}"
        routing.halt 500, { message: 'Unknown server error' }.to_json
      end

      # GET api/v1/wallets
      routing.get do
        current_account_id = routing.params['current_account_id']
        routing.halt 401, { message: 'Missing current_account_id' }.to_json unless current_account_id

        output = { data: ListPaymentMethodsForAccount.call(current_account_id: current_account_id) }
        JSON.pretty_generate(output)
      rescue ListPaymentMethodsForAccount::UnknownCurrentAccountError => e
        routing.halt 404, { message: e.message }.to_json
      rescue StandardError => e
        Api.logger.error "UNKNOWN ERROR: #{e.message}"
        routing.halt 500, { message: 'Unknown server error' }.to_json
      end

      # POST api/v1/wallets
      routing.post do
        body = HttpRequest.new(routing).body_data
        current_account_id = body[:current_account_id]
        routing.halt 401, { message: 'Missing current_account_id' }.to_json unless current_account_id
        allowed_keys = %i[current_account_id name method_type account_number balance]
        illegal_keys = body.keys - allowed_keys
        routing.halt 400, { message: 'Illegal Attributes' }.to_json unless illegal_keys.empty?

        payment_method_data = body.slice(:name, :method_type, :account_number, :balance)
        new_wallet = CreatePaymentMethodForAccount.call(
          current_account_id: current_account_id,
          payment_method_data: payment_method_data
        )

        response.status = 201
        response['Location'] = "#{@wallet_route}/#{new_wallet.id}"
        { message: 'Payment method saved', data: new_wallet }.to_json
      rescue Sequel::MassAssignmentRestriction
        Api.logger.warn "MASS-ASSIGNMENT: #{body.keys}"
        routing.halt 400, { message: 'Illegal Attributes' }.to_json
      rescue CreatePaymentMethodForAccount::InvalidMethodTypeError => e
        routing.halt 400, { message: e.message }.to_json
      rescue CreatePaymentMethodForAccount::UnknownCurrentAccountError => e
        routing.halt 404, { message: e.message }.to_json
      rescue StandardError => e
        Api.logger.error "UNKNOWN ERROR: #{e.message}"
        routing.halt 500, { message: 'Unknown server error' }.to_json
      end
    end
  end
end
