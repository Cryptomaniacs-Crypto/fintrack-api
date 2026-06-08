# frozen_string_literal: true

require 'roda'
require 'json'

require_relative '../../config/environments'
require_relative 'http_request'
require_relative '../lib/auth_scope'
require_relative '../lib/google_id_token'
require_relative '../models/transaction'
require_relative '../models/wallet'
require_relative '../models/category'
require_relative '../models/account'
require_relative '../models/google_account'
require_relative '../models/role'
require_relative '../models/authorized_account'
require_relative '../models/sso_identity'
require_relative '../models/bill_split'
require_relative '../models/bill_split_participant'
require_relative '../models/bill_split_item'
require_relative '../services/get_account_by_username'
require_relative '../services/find_account_by_email'
require_relative '../services/create_account'
require_relative '../services/update_account_username'
require_relative '../services/authenticate_account'
require_relative '../services/authenticate_sso'
require_relative '../services/authorize_account'
require_relative '../services/find_or_create_sso_account'
require_relative '../services/verify_registration'
require_relative '../services/assign_role_to_account'
require_relative '../services/list_account_roles'
require_relative '../services/create_bill_split'
require_relative '../services/update_bill_split'
require_relative '../services/send_bill_split'
require_relative '../services/notify_bill_split'
require_relative '../services/pay_bill_split_share'
require_relative '../services/confirm_bill_split_payment'
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
    # Enables routing.patch / routing.delete / routing.put (Roda core only
    # ships get/post). Required by the transaction, role, and bill-split
    # mutation routes below.
    plugin :all_verbs

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
          # Every auth POST carries no auth_token, so it must be signed by the
          # app. Verify once here; @request_data is the verified inner body.
          begin
            @request_data = HttpRequest.new(routing).signed_body_data
          rescue SignedRequest::VerificationError
            routing.halt 403, { message: 'Must sign request' }.to_json
          end

          # POST api/v1/auth/authentication
          routing.post 'authentication' do
            account = AuthenticateAccount.call(
              username: @request_data[:username],
              password: @request_data[:password]
            )

            roles = account.system_roles.map { |role| { id: role.id, name: role.name } }
            envelope = JSON.parse(account.to_json)
            envelope['included'] = { system_roles: roles }
            policy = ::FinanceTracker::AccountPolicy.new(account)
            envelope['policies'] = policy.summary
            envelope['capabilities'] = policy.capabilities
            # Login issues a FULL-scope session token (write implies read).
            envelope['auth_token'] = AuthorizedAccount.new(envelope, AuthScope.new, account_id: account.id).token
            # Also mint a READ_ONLY API key the app can forward on behalf of the user.
            envelope['account_api_token'] = AuthorizedAccount.new(envelope, AuthScope::READ_ONLY, account_id: account.id).token
            JSON.generate(envelope)
          rescue AuthenticateAccount::UnauthorizedError => e
            routing.halt 401, { message: e.message }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end

          # POST api/v1/auth/register
          routing.post 'register' do
            VerifyRegistration.new(@request_data).call
            response.status = 202
            { message: 'Verification email sent' }.to_json
          rescue VerifyRegistration::InvalidRegistration => e
            routing.halt 400, { message: e.message }.to_json
          rescue VerifyRegistration::EmailProviderError => e
            Api.logger.error("Registration email failed: #{e.message}")
            routing.halt 500, { message: 'Could not send verification email' }.to_json
          rescue StandardError => e
            Api.logger.error "UNKNOWN ERROR: #{e.message}"
            routing.halt 500, { message: 'Unknown server error' }.to_json
          end

          # POST api/v1/auth/sso
          routing.post 'sso' do
            id_token = @request_data[:id_token]
            routing.halt(400, { message: 'Missing id_token' }.to_json) if id_token.to_s.empty?

            JSON.generate(AuthenticateSso.call(id_token))
          rescue OidcVerifier::VerificationError => e
            Api.logger.warn("SSO verification failed: #{e.message}")
            routing.halt 401, { message: 'Invalid SSO credentials' }.to_json
          rescue FindOrCreateSsoAccount::EmailConflictError
            routing.halt 409, { message: 'Email already registered to another account' }.to_json
          rescue StandardError => e
            Api.logger.error("SSO ERROR: #{e.message}")
            routing.halt 400, { message: 'SSO authentication failed' }.to_json
          end
        end

        routing.on 'accounts' do
          @account_route = "#{@api_root}/accounts"

          routing.is do
            routing.get do
              email = routing.params['email']

              if email
                # GET api/v1/accounts?email=... (search by email via HMAC hash)
                account = FindAccountByEmail.call(email:)
                next(account ? account.to_json : routing.halt(404, { message: 'Account not found' }.to_json))
              end

              # GET api/v1/accounts  (admin-only index)
              current_account = current_account_from_auth
              routing.halt 401, { message: 'Authentication required' }.to_json unless current_account
              routing.halt 403, { message: 'Admins only' }.to_json unless
                ::FinanceTracker::AccountPolicy.new(current_account, current_account, auth_scope: auth_scope).is_admin?

              role_filter = routing.params['role']
              sort = routing.params['sort']

              accounts = Account.all
              accounts = accounts.select { |a| a.system_roles.map(&:name).include?(role_filter) } if role_filter && role_filter != 'none'
              accounts = accounts.select { |a| a.system_roles.empty? } if role_filter == 'none'
              accounts = accounts.sort_by { |a| a.system_roles.map(&:name).min || 'zzz' } if sort == 'role'
              accounts = accounts.sort_by(&:username) if sort == 'username'

              {
                data: accounts.map do |a|
                  entry = JSON.parse(a.to_json)
                  entry['included'] = { 'system_roles' => a.system_roles.map { |r| { 'id' => r.id, 'name' => r.name } } }
                  entry
                end
              }.to_json
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

              # PUT api/v1/accounts/[username] -- owner renames their handle.
              routing.put do
                current_account = current_account_from_auth
                routing.halt 401, { message: 'Authentication required' }.to_json unless current_account

                target = Account.first(username:)
                routing.halt 404, { message: 'Account not found' }.to_json unless target
                routing.halt 403, { message: 'Not allowed' }.to_json unless
                  ::FinanceTracker::AccountPolicy.new(current_account, target, auth_scope: auth_scope).can_edit?

                new_username = HttpRequest.new(routing).body_data[:username]
                UpdateAccountUsername.call(account: target, new_username:).to_json
              rescue UpdateAccountUsername::InvalidUsernameError => e
                routing.halt 400, { message: e.message }.to_json
              rescue UpdateAccountUsername::UsernameTakenError => e
                routing.halt 409, { message: e.message }.to_json
              rescue StandardError => e
                Api.logger.error "USERNAME UPDATE ERROR: #{e.message}"
                routing.halt 500, { message: 'Unknown server error' }.to_json
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

              routing.on String do |role_name|
                current_account = current_account_from_auth
                target = Account.first(username:)
                routing.halt 404, { message: 'Account not found' }.to_json unless target
                routing.halt 401, { message: 'Authentication required' }.to_json unless current_account
                routing.halt(403, { message: 'Only admins can manage system roles' }.to_json) unless
                  ::FinanceTracker::SystemRolePolicy.new(current_account, target, auth_scope: auth_scope).can_manage?

                # POST api/v1/accounts/[username]/roles/[role_name]
                routing.post do
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

                # DELETE api/v1/accounts/[username]/roles/[role_name]
                routing.delete do
                  routing.halt 400, { message: 'Unknown role' }.to_json unless %w[admin creator member].include?(role_name)
                  role = Role.first(name: role_name)
                  routing.halt 404, { message: 'Role not assigned' }.to_json unless role && target.system_roles.include?(role)

                  target.remove_system_role(role)
                  { message: 'System role revoked', data: JSON.parse(target.to_json) }.to_json
                end
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

            # PATCH api/v1/transactions/[transaction_id]
            routing.patch do
              data = HttpRequest.new(routing).body_data
              current_account = current_account_from_auth
              scope_allows_write!(routing, 'transactions')

              transaction = Transaction.first(id: transaction_id)
              routing.halt 404, { message: 'Transaction not found' }.to_json unless transaction

              if current_account
                policy = ::FinanceTracker::TransactionPolicy.new(current_account, transaction, auth_scope: auth_scope)
                routing.halt 403, { message: 'Not authorized' }.to_json unless policy.can_edit?
              end

              amount_val = data.delete('amount') || data.delete(:amount)
              safe = data.slice('title', 'transaction_date', 'note', 'category_id')
                        .transform_keys(&:to_sym)
              transaction.update(safe) unless safe.empty?

              if amount_val
                transaction.amount = amount_val.to_s
                transaction.save_changes
              end

              response.status = 200
              envelope = JSON.parse(transaction.to_json)
              { message: 'Transaction updated', data: envelope }.to_json
            rescue StandardError => e
              Api.logger.error "PATCH TRANSACTION ERROR: #{e.message}"
              routing.halt 500, { message: e.message }.to_json
            end

            # DELETE api/v1/transactions/[transaction_id]
            routing.delete do
              current_account = current_account_from_auth
              scope_allows_write!(routing, 'transactions')

              transaction = Transaction.first(id: transaction_id)
              routing.halt 404, { message: 'Transaction not found' }.to_json unless transaction

              if current_account
                policy = ::FinanceTracker::TransactionPolicy.new(current_account, transaction, auth_scope: auth_scope)
                routing.halt 403, { message: 'Not authorized' }.to_json unless policy.can_delete?
              end

              transaction.destroy
              response.status = 204
              nil
            rescue StandardError => e
              Api.logger.error "DELETE TRANSACTION ERROR: #{e.message}"
              routing.halt 500, { message: e.message }.to_json
            end
          end

          # GET api/v1/transactions[?wallet_id=]
          routing.get do
            current_account = current_account_from_auth
            scope = current_account ? ::FinanceTracker::TransactionScope.new(current_account).viewable : Transaction
            wallet_id = routing.params['wallet_id']
            scope = scope.where(wallet_id: wallet_id) if wallet_id
            transactions = scope.order(Sequel.desc(:transaction_date)).all
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

        routing.on 'bill-splits' do
          current_account = current_account_from_auth
          routing.halt 401, { message: 'Authentication required' }.to_json unless current_account

          routing.is do
            # GET api/v1/bill-splits — splits where current account is creator or participant
            routing.get do
              created = BillSplit.where(creator_id: current_account.id).all
              shared_ids = BillSplitParticipant.where(account_id: current_account.id).select_map(:bill_split_id)
              shared = shared_ids.empty? ? [] : BillSplit.where(id: shared_ids).all
              bills = (created + shared).uniq(&:id).sort_by { |bill| bill.created_at.to_s }.reverse
              { data: bills.map(&:to_h) }.to_json
            rescue StandardError => e
              Api.logger.error "UNKNOWN ERROR: #{e.message}"
              routing.halt 500, { message: 'Unknown server error' }.to_json
            end

            # POST api/v1/bill-splits — create a draft (creator + named participants)
            routing.post do
              scope_allows_write!(routing, 'transactions')
              payload = HttpRequest.new(routing).body_data

              bill = CreateBillSplit.call(
                creator: current_account,
                title: payload[:title] || payload['title'],
                participant_usernames: payload[:participant_usernames] || payload['participant_usernames'],
                note: payload[:note] || payload['note']
              )

              response.status = 201
              response['Location'] = "#{@api_root}/bill-splits/#{bill.id}"
              bill.to_json
            rescue CreateBillSplit::UnknownParticipant => e
              routing.halt 404, { message: e.message }.to_json
            rescue CreateBillSplit::InvalidInput => e
              routing.halt 400, { message: e.message }.to_json
            rescue JSON::ParserError
              routing.halt 400, { message: 'Invalid JSON body' }.to_json
            rescue StandardError => e
              Api.logger.error "UNKNOWN ERROR: #{e.message}"
              routing.halt 500, { message: 'Unknown server error' }.to_json
            end
          end

          routing.on String do |split_id|
            bill = BillSplit.first(id: split_id)
            routing.halt 404, { message: 'Bill split not found' }.to_json unless bill
            routing.halt 403, { message: 'Not authorized to access this bill split' }.to_json unless bill.participant?(current_account)

            routing.is do
              # GET api/v1/bill-splits/[id] — detail + per-person breakdown
              routing.get do
                bill.to_json
              end

              # PATCH api/v1/bill-splits/[id] — creator edits dishes/tax/service while editable
              routing.patch do
                scope_allows_write!(routing, 'transactions')
                routing.halt 403, { message: 'Only the creator can edit a bill split' }.to_json unless bill.creator?(current_account)

                payload = HttpRequest.new(routing).body_data
                updated = UpdateBillSplit.call(
                  bill_split: bill,
                  title: payload[:title] || payload['title'],
                  tax_percent: payload[:tax_percent] || payload['tax_percent'],
                  service_percent: payload[:service_percent] || payload['service_percent'],
                  note: payload[:note] || payload['note'],
                  items: payload[:items] || payload['items']
                )
                updated.to_json
              rescue UpdateBillSplit::NotEditable => e
                routing.halt 409, { message: e.message }.to_json
              rescue UpdateBillSplit::InvalidInput => e
                routing.halt 400, { message: e.message }.to_json
              end

              # DELETE api/v1/bill-splits/[id] — creator may delete while not settled
              routing.delete do
                scope_allows_write!(routing, 'transactions')
                routing.halt 403, { message: 'Only the creator can delete a bill split' }.to_json unless bill.creator?(current_account)
                routing.halt 409, { message: 'Settled records cannot be deleted' }.to_json if bill.settled?

                bill.destroy
                { message: 'Bill split deleted' }.to_json
              end
            end

            # POST api/v1/bill-splits/[id]/send — owner sends; optional wallet_id
            # records the owner's upfront expense for the grand total.
            routing.post 'send' do
              scope_allows_write!(routing, 'transactions')
              routing.halt 403, { message: 'Only the creator can send a bill split' }.to_json unless bill.creator?(current_account)

              payload = HttpRequest.new(routing).body_data
              SendBillSplit.call(bill:, owner: current_account, wallet_id: payload[:wallet_id] || payload['wallet_id'])
              bill.reload
              NotifyBillSplit.call(bill: bill, app_url: ENV.fetch('APP_URL', nil))
              bill.to_json
            rescue SendBillSplit::InvalidInput => e
              routing.halt 400, { message: e.message }.to_json
            end

            # POST api/v1/bill-splits/[id]/agree — a participant agrees to their share
            routing.post 'agree' do
              scope_allows_write!(routing, 'transactions')
              participant = bill.participant_for(current_account)
              routing.halt 403, { message: 'Only a participant can agree' }.to_json unless participant
              routing.halt 409, { message: 'Cannot change a paid or settled share' }.to_json if participant.paid? || participant.settled?

              participant.agree!
              bill.reload.to_json
            rescue StandardError => e
              routing.halt 400, { message: e.message }.to_json
            end

            # POST api/v1/bill-splits/[id]/reject — a participant rejects with a note
            routing.post 'reject' do
              scope_allows_write!(routing, 'transactions')
              participant = bill.participant_for(current_account)
              routing.halt 403, { message: 'Only a participant can reject' }.to_json unless participant
              routing.halt 409, { message: 'Cannot reject a paid or settled share' }.to_json if participant.paid? || participant.settled?

              payload = HttpRequest.new(routing).body_data
              reason = (payload[:reason] || payload['reason']).to_s.strip
              routing.halt 400, { message: 'Reject reason is required' }.to_json if reason.empty?

              participant.reject!(reason)
              bill.mark_disputed!
              bill.reload.to_json
            rescue StandardError => e
              routing.halt 400, { message: e.message }.to_json
            end

            # POST api/v1/bill-splits/[id]/pay — a participant records payment from
            # one of their wallets, optionally attaching a proof image.
            routing.post 'pay' do
              scope_allows_write!(routing, 'transactions')
              payload = HttpRequest.new(routing).body_data
              PayBillSplitShare.call(
                bill:,
                payer: current_account,
                wallet_id: payload[:wallet_id] || payload['wallet_id'],
                proof_base64: payload[:proof_base64] || payload['proof_base64'],
                proof_content_type: payload[:proof_content_type] || payload['proof_content_type']
              )
              bill.reload.to_json
            rescue PayBillSplitShare::NotAllowed => e
              routing.halt 403, { message: e.message }.to_json
            rescue PayBillSplitShare::InvalidInput => e
              routing.halt 400, { message: e.message }.to_json
            end

            routing.on 'participants' do
              routing.on String do |participant_id|
                participant = bill.participants.find { |p| p.id == participant_id }
                routing.halt 404, { message: 'Participant not found' }.to_json unless participant

                # POST .../participants/[pid]/confirm — owner confirms receipt (income)
                routing.post 'confirm' do
                  scope_allows_write!(routing, 'transactions')
                  payload = HttpRequest.new(routing).body_data
                  ConfirmBillSplitPayment.call(
                    bill:, owner: current_account, participant:,
                    wallet_id: payload[:wallet_id] || payload['wallet_id']
                  )
                  bill.reload.to_json
                rescue ConfirmBillSplitPayment::NotAllowed => e
                  routing.halt 403, { message: e.message }.to_json
                rescue ConfirmBillSplitPayment::InvalidInput => e
                  routing.halt 400, { message: e.message }.to_json
                end

                # GET .../participants/[pid]/proof — owner or that participant only
                routing.get 'proof' do
                  unless bill.creator?(current_account) || participant.account_id == current_account.id
                    routing.halt 403, { message: 'Not authorized to view this proof' }.to_json
                  end
                  routing.halt 404, { message: 'No proof uploaded' }.to_json unless participant.proof?

                  { content_type: participant.proof_content_type, image_base64: participant.proof_image }.to_json
                end
              end
            end
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
