# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative '../models/transaction'
require_relative '../models/wallet'
require_relative '../models/category'
require_relative '../models/account'
require_relative '../models/role'

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
        routing.on 'accounts' do
          @account_route = "#{@api_root}/accounts"

          # GET api/v1/accounts/[username]
          routing.get String do |username|
            account = Account.first(username:)
            account ? account.to_json : raise('Account not found')
          rescue StandardError => e
            routing.halt 404, { message: e.message }.to_json
          end

          # GET api/v1/accounts?email=... (search by email via HMAC hash)
          routing.get do
            email = routing.params['email']
            routing.halt 400, { message: 'email query param required' }.to_json unless email

            account = Account.first(email_hash: SecureDB.hash(email))
            account ? account.to_json : routing.halt(404, { message: 'Account not found' }.to_json)
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end

          # POST api/v1/accounts
          routing.post do
            new_data = JSON.parse(routing.body.read)
            new_account = Account.new(new_data)
            raise('Could not save account') unless new_account.save_changes

            response.status = 201
            response['Location'] = "#{@account_route}/#{new_account.username}"
            new_account.to_json
          rescue Sequel::MassAssignmentRestriction
            Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
            routing.halt 400, { message: 'Illegal Attributes' }.to_json
          rescue Sequel::UniqueConstraintViolation
            routing.halt 409, { message: 'Username or email already taken' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end
        end

        routing.on 'wallets' do
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

        routing.on 'categories' do
          @category_route = "#{@api_root}/categories"

          # GET api/v1/categories/[category_id]
          routing.get String do |category_id|
            category = Category.first(id: category_id)
            category ? category.to_json : raise('Category not found')
          rescue StandardError => e
            routing.halt 404, { message: e.message }.to_json
          end

          # GET api/v1/categories
          routing.get do
            { data: Category.all }.to_json
          rescue StandardError
            routing.halt 404, { message: 'Could not find categories' }.to_json
          end

          # POST api/v1/categories
          routing.post do
            new_data = JSON.parse(routing.body.read)
            new_category = Category.new(new_data)
            raise('Could not save category') unless new_category.save_changes

            response.status = 201
            response['Location'] = "#{@category_route}/#{new_category.id}"
            { message: 'Category saved', data: new_category }.to_json
          rescue Sequel::MassAssignmentRestriction
            Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
            routing.halt 400, { message: 'Illegal Attributes' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end
        end

        routing.on 'transactions' do
          @transaction_route = "#{@api_root}/transactions"

          routing.on String do |transaction_id|
            routing.on 'wallet' do
              # GET api/v1/transactions/[transaction_id]/wallet
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                wallet = transaction&.wallet
                wallet ? wallet.to_json : raise('Wallet not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end
            end

            routing.on 'category' do
              # GET api/v1/transactions/[transaction_id]/category
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                category = transaction&.category
                category ? category.to_json : raise('Category not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end
            end

            routing.on 'wallets' do
              @wallet_route = "#{@api_root}/transactions/#{transaction_id}/wallets"

              # GET api/v1/transactions/[transaction_id]/wallets/[wallet_id]
              routing.get String do |wallet_id|
                transaction = Transaction.first(id: transaction_id)
                wallet = transaction&.wallet
                wallet = nil unless wallet&.id.to_s == wallet_id.to_s
                wallet ? wallet.to_json : raise('Wallet not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/wallets
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                output = { data: transaction.wallet ? [transaction.wallet] : [] }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find wallets' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/wallets
              routing.post do
                new_data = JSON.parse(routing.body.read)
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                new_wallet = Wallet.create(new_data)
                transaction.update(wallet_id: new_wallet.id)
                raise 'Could not save wallet' unless new_wallet

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

            routing.on 'categories' do
              @category_route = "#{@api_root}/transactions/#{transaction_id}/categories"

              # GET api/v1/transactions/[transaction_id]/categories/[category_id]
              routing.get String do |category_id|
                transaction = Transaction.first(id: transaction_id)
                category = transaction&.category
                category = nil unless category&.id.to_s == category_id.to_s
                category ? category.to_json : raise('Category not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/categories
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                output = { data: transaction.category ? [transaction.category] : [] }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find categories' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/categories
              routing.post do
                new_data = JSON.parse(routing.body.read)
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                new_category = Category.new(new_data)
                raise 'Could not save category' unless new_category.save_changes
                transaction.update(category_id: new_category.id)

                response.status = 201
                response['Location'] = "#{@category_route}/#{new_category.id}"
                { message: 'Category saved', data: new_category }.to_json
              rescue Sequel::MassAssignmentRestriction
                Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
                routing.halt 400, { message: 'Illegal Attributes' }.to_json
              rescue StandardError => e
                Api.logger.error "UNKNOWN ERROR: #{e.message}"
                routing.halt 500, { message: 'Unknown server error' }.to_json
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
            new_transaction = Transaction.create(new_data)

            response.status = 201
            response['Location'] = "#{@transaction_route}/#{new_transaction.id}"
            { message: 'Transaction saved', data: new_transaction }.to_json
          rescue Sequel::MassAssignmentRestriction
            Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
            routing.halt 400, { message: 'Illegal Attributes' }.to_json
          rescue Sequel::ForeignKeyConstraintViolation
            routing.halt 404, { message: 'Wallet not found' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end
        end
      end
    end
  end
end
