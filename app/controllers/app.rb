# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../models/transaction'
require_relative '../models/wallet'
require_relative '../models/category'
require_relative '../models/account'
require_relative '../models/role'
require_relative '../services/get_account_by_username'
require_relative '../services/find_account_by_email'
require_relative '../services/create_account'
require_relative '../services/assign_role_to_account'
require_relative '../services/list_account_roles'
require_relative '../services/authenticate_account'

module FinanceTracker
  # Web controller for Finance Tracker API
  class Api < Roda
    plugin :halt
    plugin :multi_route

    route do |routing|
      response['Content-Type'] = 'application/json'

      # Block plain-HTTP requests in production
      if Api.environment == :production && routing.scheme != 'https'
        routing.halt 403, { message: 'TLS/SSL Required' }.to_json
      end

      routing.root do
        { message: 'Finance Tracker API up at /api/v1' }.to_json
      end

      routing.on 'api' do
        routing.on 'v1' do
          @api_root = 'api/v1'
          routing.multi_route
        end
      end
    end
  end
end

require_relative 'auth'
require_relative 'accounts'
require_relative 'wallets'
require_relative 'categories'
require_relative 'transactions'
