# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../models/transaction'
require_relative '../models/account'
require_relative '../models/category'

module FinanceTracker
  # Web controller for Finance Tracker API
  class Api < Roda
    plugin :halt

    route do |routing|
      response['Content-Type'] = 'application/json'

      routing.root do
        { message: 'Finance Tracker API up at /api/v1' }.to_json
      end

      @api_root = 'api/v1'
      routing.on @api_root do

        #ACCOUNTS ROOT
        routing.on 'accounts' do
          @account_route = "#{@api_root}/accounts"

          routing.on String do |account_id|
            # GET api/v1/accounts/[account_id]
            routing.get do
              account = Account.first(id: account_id)
              account ? account.to_json : raise('Account not found')
            rescue StandardError => e
              routing.halt 404, { message: e.message }.to_json
            end
          end

          # GET api/v1/accounts
          routing.get do
            output = { data: Account.all }
            JSON.pretty_generate(output)
          rescue StandardError
            routing.halt 404, { message: 'Could not find accounts' }.to_json
          end

          # POST api/v1/accounts
          routing.post do
            new_data = JSON.parse(routing.body.read)
            new_account = Account.new(new_data)
            raise('Could not save account') unless new_account.save_changes

            response.status = 201
            response['Location'] = "#{@account_route}/#{new_account.id}"
            new_account.to_json
          rescue StandardError => e
            routing.halt 400, { message: e.message }.to_json
          end
        end

        #CATEGORIES
        routing.on 'categories' do
          @category_route = "#{@api_root}/categories"

          routing.on String do |category_id|
            routing.get do
              category = Category.first(id: category_id)
              category ? category.to_json : raise('Category not found')
            rescue StandardError => e
              routing.halt 404, { message: e.message }.to_json
            end
          end

          routing.get do
            output = { data: Category.all }
            JSON.pretty_generate(output)
          rescue StandardError
            routing.halt 404, { message: 'Could not find categories' }.to_json
          end

          routing.post do
            new_data = JSON.parse(routing.body.read)
            new_category = Category.new(new_data)
            raise('Could not save category') unless new_category.save_changes

            response.status = 201
            response['Location'] = "#{@category_route}/#{new_category.id}"
            new_category.to_json
          rescue StandardError => e
            routing.halt 400, { message: e.message }.to_json
          end
        end

        #TRANSACTIONS
        routing.on 'transactions' do
          @transaction_route = "#{@api_root}/transactions"

          routing.on String do |transaction_id|

            routing.on 'account' do
              @account_route = "#{@api_root}/transactions/#{transaction_id}/account"
              # GET api/v1/transactions/[transaction_id]/account/[account_id]
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                account = transaction&.account
                account ? account.to_json : raise('Account not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end
            end
            
            routing.on 'category' do
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                category = transaction&.category
                category ? category.to_json : raise('Category not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end
            end
            # GET api/v1/transactions/[transaction_id] TO FIND SPECIFIC TRANSACTION
            routing.get do
              transaction = Transaction.first(id: transaction_id)
              transaction ? transaction.to_json : raise('Transaction not found')
            rescue StandardError => e
              routing.halt 404, { message: e.message }.to_json
            end
          end

          #TO FIND ALL TRANSACTION
          routing.get do
            output = { data: Transaction.all }
            JSON.pretty_generate(output)
          rescue StandardError
            routing.halt 404, { message: 'Could not find transactions' }.to_json
          end

          # POST api/v1/transactions
          routing.post do
            new_data = JSON.parse(routing.body.read)
            account = Account.first(id: new_data['account_id'])
            routing.halt 404, { message: 'Account not found' }.to_json unless account

            new_transaction = Transaction.new(new_data)
            raise('Could not save transaction') unless new_transaction.save_changes

            response.status = 201
            response['Location'] = "#{@transaction_route}/#{new_transaction.id}"
            new_transaction.to_json
          rescue StandardError
            routing.halt 500, { message: 'Database error' }.to_json
          end
        end
      end
    end
  end
end
