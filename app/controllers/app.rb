# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative 'http_request'
require_relative '../lib/auth_scope'
require_relative '../models/transaction'
require_relative '../models/wallet'
require_relative '../models/category'
require_relative '../models/account'
require_relative '../models/role'
require_relative '../models/authorized_account'
require_relative '../services/get_account_by_username'
require_relative '../services/find_account_by_email'
require_relative '../services/create_account'
require_relative '../services/authenticate_account'
require_relative '../services/authorize_account'
require_relative '../services/verify_registration'
require_relative '../services/assign_role_to_account'
require_relative '../services/list_account_roles'
require_relative '../policies/account_policy'
require_relative '../policies/account_scope'
require_relative '../policies/category_policy'
require_relative '../policies/category_scope'
require_relative '../policies/system_role_policy'
require_relative '../policies/transaction_policy'
require_relative '../policies/transaction_scope'
require_relative '../policies/wallet_policy'
require_relative '../policies/wallet_scope'

module FinanceTracker
  # Web controller for Finance Tracker API
  class Api < Roda
    plugin :halt

    route do |routing|
      response['Content-Type'] = 'application/json'

      # Decrypt the Bearer token once per request into an AuthorizedAccount
      # (identity payload + AuthScope). A present-but-bad token is a hard 401
      # rather than a silent downgrade to anonymous access.
      begin
        @auth = HttpRequest.new(routing).authorized_account
        @auth_account = @auth&.account
      rescue AuthToken::InvalidTokenError
        routing.halt 401, { message: 'Invalid auth token' }.to_json
      rescue AuthToken::ExpiredTokenError
        routing.halt 401, { message: 'Expired auth token' }.to_json
      end

      routing.root do
        { message: 'Finance Tracker API up at /api/v1' }.to_json
      end

      @api_root = 'api/v1'
      routing.on @api_root do
        routing.on 'auth' do
          # POST api/v1/auth/authentication
          routing.post 'authentication' do
            credentials = JSON.parse(routing.body.read)
            account = AuthenticateAccount.call(
              username: credentials['username'],
              password: credentials['password']
            )

            roles = account.system_roles.map { |role| { id: role.id, name: role.name } }
            envelope = JSON.parse(account.to_json)
            envelope['included'] = { system_roles: roles }
            policy = ::FinanceTracker::AccountPolicy.new(account)
            envelope['policies'] = policy.summary
            envelope['capabilities'] = policy.capabilities
            # Login issues a FULL-scope session token (write implies read).
            envelope['auth_token'] = AuthorizedAccount.new(envelope, AuthScope.new, account_id: account.id).token
            JSON.generate(envelope)
          rescue AuthenticateAccount::UnauthorizedError => e
            routing.halt 401, { message: e.message }.to_json
          rescue JSON::ParserError
            routing.halt 400, { message: 'Invalid JSON body' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end

          # POST api/v1/auth/register
          routing.post 'register' do
            registration = JSON.parse(routing.body.read)
            VerifyRegistration.new(registration).call
            response.status = 202
            { message: 'Verification email sent' }.to_json
          rescue VerifyRegistration::InvalidRegistration => e
            routing.halt 400, { message: e.message }.to_json
          rescue VerifyRegistration::EmailProviderError => e
            Api.logger.error("Registration email failed: #{e.message}")
            routing.halt 500, { message: 'Could not send verification email' }.to_json
          rescue JSON::ParserError
            routing.halt 400, { message: 'Invalid JSON body' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end
        end

        routing.on 'accounts' do
          @account_route = "#{@api_root}/accounts"

          routing.is do
            # GET api/v1/accounts?email=... (search by email via HMAC hash)
            routing.get do
              email = routing.params['email']
              routing.halt 400, { message: 'email query param required' }.to_json unless email

              account = FindAccountByEmail.call(email:)
              account ? account.to_json : routing.halt(404, { message: 'Account not found' }.to_json)
            rescue StandardError => e
              Api.logger.error "UNKNOWN ERROR: #{e.message}"
              routing.halt 500, { message: 'Unknown server error' }.to_json
            end

            # POST api/v1/accounts
            routing.post do
              new_data = JSON.parse(routing.body.read)
              new_account = CreateAccount.call(account_data: new_data)

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

          routing.on String do |username|
            # GET api/v1/accounts/[username]
            # Returns account details; an authenticated owner additionally
            # receives a limited-scope (READ_ONLY) auth_token to use as an API key.
            routing.is do
              routing.get do
                envelope = AuthorizeAccount.call(auth: @auth, username:)
                envelope.to_json
              rescue GetAccountByUsername::AccountNotFoundError => e
                routing.halt 404, { message: e.message }.to_json
              rescue AuthorizeAccount::ForbiddenError
                routing.halt 404, { message: 'Account not found' }.to_json
              end
            end

            routing.on 'roles' do
              @account_roles_route = "#{@api_root}/accounts/#{username}/roles"

              # GET api/v1/accounts/[username]/roles
              routing.get do
                current_account = current_account_from_auth
                target = Account.first(username:)
                if current_account
                  routing.halt 403, { message: 'Only admins can manage system roles' }.to_json unless
                    ::FinanceTracker::SystemRolePolicy.new(current_account, target, auth_scope: auth_scope).can_manage?
                end

                roles = ListAccountRoles.call(username:).map { |role| { id: role.id, name: role.name } }
                output = { data: roles }
                JSON.pretty_generate(output)
              rescue ListAccountRoles::AccountNotFoundError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # POST api/v1/accounts/[username]/roles/[role_name]
              routing.post String do |role_name|
                current_account = current_account_from_auth
                target = Account.first(username:)
                if current_account
                  routing.halt(403, { message: 'Only admins can manage system roles' }.to_json) unless
                    ::FinanceTracker::SystemRolePolicy.new(current_account, target, auth_scope: auth_scope).can_manage?
                end

                assigned_role = AssignRoleToAccount.call(username:, role_name:)

                response.status = 201
                response['Location'] = "#{@account_roles_route}/#{assigned_role.name}"
                assigned_role.to_json
              rescue AssignRoleToAccount::AccountNotFoundError,
                     AssignRoleToAccount::RoleNotFoundError => e
                routing.halt 404, { message: e.message }.to_json
              rescue AssignRoleToAccount::RoleAlreadyAssignedError => e
                routing.halt 409, { message: e.message }.to_json
              end

            end
          end
        end

        routing.on 'wallets' do
          @wallet_route = "#{@api_root}/wallets"

          # GET api/v1/wallets/[wallet_id]
          routing.get String do |wallet_id|
            wallet = Wallet.first(id: wallet_id)
            current_account = current_account_from_auth
            if current_account
              routing.halt(404, { message: 'Wallet not found' }.to_json) unless ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).can_view?
            end

            if wallet
              envelope = JSON.parse(wallet.to_json)
              envelope['policies'] = ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).summary if current_account
              envelope.to_json
            else
              raise('Wallet not found')
            end
          rescue StandardError => e
            routing.halt 404, { message: e.message }.to_json
          end

          # GET api/v1/wallets
          routing.get do
            current_account = current_account_from_auth
            wallets = current_account ? ::FinanceTracker::WalletScope.new(current_account).viewable.all : Wallet.all
            payload = wallets.map do |wallet|
              envelope = JSON.parse(wallet.to_json)
              envelope['policies'] = ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).index_summary if current_account
              envelope
            end
            { data: payload }.to_json
          rescue StandardError
            routing.halt 404, { message: 'Could not find wallets' }.to_json
          end

          # POST api/v1/wallets
          routing.post do
            request = HttpRequest.new(routing)
            new_data = request.body_data
            current_account = current_account_from_auth
            scope_allows_write!(routing, 'wallets')
            new_data[:account_id] ||= current_account&.id
            new_wallet = Wallet.create(new_data)

            response.status = 201
            response['Location'] = "#{@wallet_route}/#{new_wallet.id}"
            envelope = JSON.parse(new_wallet.to_json)
            envelope['policies'] = current_account ? ::FinanceTracker::WalletPolicy.new(current_account, new_wallet, auth_scope: auth_scope).summary : {}
            { message: 'Wallet saved', data: envelope }.to_json
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
            current_account = current_account_from_auth
            if current_account
              routing.halt(404, { message: 'Category not found' }.to_json) unless ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).can_view?
            end

            if category
              envelope = JSON.parse(category.to_json)
              envelope['policies'] = ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).summary if current_account
              envelope.to_json
            else
              raise('Category not found')
            end
          rescue StandardError => e
            routing.halt 404, { message: e.message }.to_json
          end

          # GET api/v1/categories
          routing.get do
            current_account = current_account_from_auth
            categories = current_account ? ::FinanceTracker::CategoryScope.new(current_account).viewable.all : Category.all
            payload = categories.map do |category|
              envelope = JSON.parse(category.to_json)
              envelope['policies'] = ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).index_summary if current_account
              envelope
            end
            { data: payload }.to_json
          rescue StandardError
            routing.halt 404, { message: 'Could not find categories' }.to_json
          end

          # POST api/v1/categories
          routing.post do
            request = HttpRequest.new(routing)
            new_data = request.body_data
            current_account = current_account_from_auth
            scope_allows_write!(routing, 'categories')
            new_category = Category.new(new_data)
            raise('Could not save category') unless new_category.save_changes

            response.status = 201
            response['Location'] = "#{@category_route}/#{new_category.id}"
            envelope = JSON.parse(new_category.to_json)
            envelope['policies'] = current_account ? ::FinanceTracker::CategoryPolicy.new(current_account, new_category, auth_scope: auth_scope).summary : {}
            { message: 'Category saved', data: envelope }.to_json
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
                current_account = current_account_from_auth
                if current_account && wallet
                  routing.halt(404, { message: 'Wallet not found' }.to_json) unless ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).can_view?
                end
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
                current_account = current_account_from_auth
                if current_account && category
                  routing.halt(404, { message: 'Category not found' }.to_json) unless ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).can_view?
                end
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
                current_account = current_account_from_auth
                if current_account && wallet
                  routing.halt(404, { message: 'Wallet not found' }.to_json) unless ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).can_view?
                end
                wallet ? wallet.to_json : raise('Wallet not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/wallets
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                current_account = current_account_from_auth
                wallet = transaction.wallet
                if current_account && wallet
                  routing.halt(404, { message: 'Wallet not found' }.to_json) unless ::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).can_view?
                end

                output = { data: wallet ? [wallet] : [] }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find wallets' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/wallets
              routing.post do
                request = HttpRequest.new(routing)
                new_data = request.body_data
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                current_account = current_account_from_auth
                scope_allows_write!(routing, 'wallets')
                new_data[:account_id] ||= current_account&.id
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
                current_account = current_account_from_auth
                if current_account && category
                  routing.halt(404, { message: 'Category not found' }.to_json) unless ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).can_view?
                end
                category ? category.to_json : raise('Category not found')
              rescue StandardError => e
                routing.halt 404, { message: e.message }.to_json
              end

              # GET api/v1/transactions/[transaction_id]/categories
              routing.get do
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                current_account = current_account_from_auth
                category = transaction.category
                if current_account && category
                  routing.halt(404, { message: 'Category not found' }.to_json) unless ::FinanceTracker::CategoryPolicy.new(current_account, category, auth_scope: auth_scope).can_view?
                end

                output = { data: category ? [category] : [] }
                JSON.pretty_generate(output)
              rescue StandardError
                routing.halt 404, { message: 'Could not find categories' }.to_json
              end

              # POST api/v1/transactions/[transaction_id]/categories
              routing.post do
                request = HttpRequest.new(routing)
                new_data = request.body_data
                transaction = Transaction.first(id: transaction_id)
                raise 'Transaction not found' unless transaction

                scope_allows_write!(routing, 'categories')
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
              current_account = current_account_from_auth
              if current_account && transaction
                routing.halt(404, { message: 'Transaction not found' }.to_json) unless ::FinanceTracker::TransactionPolicy.new(current_account, transaction, auth_scope: auth_scope).can_view?
              end
              if transaction
                envelope = JSON.parse(transaction.to_json)
                envelope['policies'] = ::FinanceTracker::TransactionPolicy.new(current_account, transaction, auth_scope: auth_scope).summary if current_account
                envelope.to_json
              else
                raise('Transaction not found')
              end
            rescue StandardError => e
              routing.halt 404, { message: e.message }.to_json
            end
          end

          # GET api/v1/transactions
          routing.get do
            current_account = current_account_from_auth
            transactions = current_account ? ::FinanceTracker::TransactionScope.new(current_account).viewable.all : Transaction.all
            payload = transactions.map do |transaction|
              envelope = JSON.parse(transaction.to_json)
              envelope['policies'] = ::FinanceTracker::TransactionPolicy.new(current_account, transaction, auth_scope: auth_scope).index_summary if current_account
              envelope
            end
            output = { data: payload }
            JSON.pretty_generate(output)
          rescue StandardError
            routing.halt 404, { message: 'Could not find transactions' }.to_json
          end

          # POST api/v1/transactions
          routing.post do
            request = HttpRequest.new(routing)
            new_data = request.body_data
            current_account = current_account_from_auth
            scope_allows_write!(routing, 'transactions')
            wallet_id = new_data['wallet_id'] || new_data[:wallet_id]
            if wallet_id
              wallet = Wallet.first(id: wallet_id)
              raise Sequel::ForeignKeyConstraintViolation, 'Wallet not found' unless wallet

              if current_account && !::FinanceTracker::WalletPolicy.new(current_account, wallet, auth_scope: auth_scope).can_view?
                routing.halt 404, { message: 'Wallet not found' }.to_json
              end
            end

            new_transaction = Transaction.create(new_data)

            response.status = 201
            response['Location'] = "#{@transaction_route}/#{new_transaction.id}"
            envelope = JSON.parse(new_transaction.to_json)
            envelope['policies'] = current_account ? ::FinanceTracker::TransactionPolicy.new(current_account, new_transaction, auth_scope: auth_scope).summary : {}
            { message: 'Transaction saved', data: envelope }.to_json
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

    private

    # The Account model behind the current request's token, or nil when no
    # (valid) token was presented. Re-derived from the id inside the token so
    # roles/policies always reflect live DB state.
    def current_account_from_auth
      return @current_account_from_auth if defined?(@current_account_from_auth)

      account_id = @auth_account&.dig('attributes', 'id')
      @current_account_from_auth = account_id ? Account.first(id: account_id) : nil
    end

    # The AuthScope carried by the current token (FULL when no token present).
    def auth_scope
      @resolved_auth_scope ||= @auth&.scope || AuthScope.new
    end

    # Enforce the token's write scope on mutating routes. Only applies when a
    # token is present: anonymous requests keep their existing (open) behavior,
    # so this narrows authenticated tokens (e.g. a READ_ONLY API key) without
    # changing the unauthenticated surface.
    def scope_allows_write!(routing, resource)
      return unless @auth
      return if auth_scope.can_write?(resource)

      routing.halt 403, { message: "Auth token scope does not permit writing #{resource}" }.to_json
    end
  end
end
