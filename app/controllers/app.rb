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
        routing.on 'transactions' do
          @transaction_route = "#{@api_root}/transactions"

          routing.on String do |transaction_id|
            routing.on 'accounts' do
              @account_route = "#{@api_root}/transactions/#{transaction_id}/accounts"

              # GET api/v1/transactions/[transaction_id]/accounts/[account_id]
              routing.get String do |account_id|
                account = Account.where(transaction_id:, id: account_id).first
                account ? account.to_json : raise('Account not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/accounts
              routing.get do
                output = { data: Transaction.first(id: transaction_id).accounts }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find accounts' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/accounts
              routing.post do
                new_data = JSON.parse(routing.body.read)
                transaction = Transaction.first(id: transaction_id)
                new_account = transaction.add_account(new_data)

                if new_account
                  response.status = 201
                  response['Location'] = "#{@account_route}/#{new_account.id}"
                  { message: 'Account saved', data: new_account }.to_json
                else
                  routing.halt 400, { message: 'Could not save account' }.to_json
                end
              rescue StandardError
                routing.halt 500, { message: 'Database error' }.to_json
              end
            end

            routing.on 'categories' do
              @category_route = "#{@api_root}/transactions/#{transaction_id}/categories"

              # GET api/v1/transactions/[transaction_id]/categories/[category_id]
              routing.get String do |category_id|
                category = Category.where(transaction_id:, id: category_id).first
                category ? category.to_json : raise('Category not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/categories
              routing.get do
                output = { data: Transaction.first(id: transaction_id).categories }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find categories' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/categories
              routing.post do
                new_data = JSON.parse(routing.body.read)
                transaction = Transaction.first(id: transaction_id)
                new_category = transaction.add_category(new_data)

                if new_category
                  response.status = 201
                  response['Location'] = "#{@category_route}/#{new_category.id}"
                  { message: 'Category saved', data: new_category }.to_json
                else
                  routing.halt 400, { message: 'Could not save category' }.to_json
                end
              rescue StandardError
                routing.halt 500, { message: 'Database error' }.to_json
              end
            end

            # GET api/v1/transactions/[transaction_id]
            routing.get do
              transaction = Transaction.first(id: transaction_id)
              transaction ? transaction.to_json : raise('Transaction not found')
            rescue StandardError => e
              routing.halt 404, { message: e.message }.to_json
            end
          end

          # GET api/v1/transactions
          routing.get do
            output = { data: Transaction.all }
            JSON.pretty_generate(output)
          rescue StandardError
            routing.halt 404, { message: 'Could not find transactions' }.to_json
          end

          # POST api/v1/transactions
          routing.post do
            new_data = JSON.parse(routing.body.read)
            new_transaction = Transaction.new(new_data)
            raise('Could not save transaction') unless new_transaction.save_changes

            response.status = 201
            response['Location'] = "#{@transaction_route}/#{new_transaction.id}"
            { message: 'Transaction saved', data: new_transaction }.to_json
          rescue StandardError => e
            routing.halt 400, { message: e.message }.to_json
          end
        end
      end
    end
  end
end
