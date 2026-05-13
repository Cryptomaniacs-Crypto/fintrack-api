# frozen_string_literal: true

require_relative 'app'

module FinanceTracker
  # Account routes
  class Api < Roda
    route('accounts') do |routing|
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
        routing.is do
          routing.get do
            GetAccountByUsername.call(username:).to_json
          rescue GetAccountByUsername::AccountNotFoundError => e
            routing.halt 404, { message: e.message }.to_json
          end
        end

        routing.on 'roles' do
          @account_roles_route = "#{@api_root}/accounts/#{username}/roles"

          # GET api/v1/accounts/[username]/roles
          routing.get do
            roles = ListAccountRoles.call(username:).map { |role| { id: role.id, name: role.name } }
            output = { data: roles }
            JSON.pretty_generate(output)
          rescue ListAccountRoles::AccountNotFoundError => e
            routing.halt 404, { message: e.message }.to_json
          end

          # POST api/v1/accounts/[username]/roles/[role_name]
          routing.post String do |role_name|
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
  end
end
