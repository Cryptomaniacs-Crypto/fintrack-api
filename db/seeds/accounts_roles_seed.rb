# frozen_string_literal: true

require_relative '../../app/models/role'
require_relative '../../app/models/account'
require_relative '../../app/services/create_account'
require_relative '../../app/services/assign_role_to_account'

module FinanceTracker
  # Seed helpers for accounts and system roles.
  module AccountsRolesSeed
    SEED_ACCOUNTS = [
      {
        'username' => 'admin.user',
        'email' => 'admin@example.com',
        'password' => 'admin-password',
        'avatar' => 'admin.png',
        'role_name' => 'admin'
      },
      {
        'username' => 'member.user',
        'email' => 'member@example.com',
        'password' => 'member-password',
        'avatar' => 'member.png',
        'role_name' => 'member'
      }
    ].freeze

    def self.run
      %w[admin member].each do |role_name|
        Role.find(name: role_name) || Role.create(name: role_name)
      end

      SEED_ACCOUNTS.each do |account_data|
        role_name = account_data['role_name']
        account = Account.find(username: account_data['username']) ||
                  CreateAccount.call(account_data: account_data.reject { |k, _| k == 'role_name' })

        next if account.system_roles_dataset.where(name: role_name).first

        AssignRoleToAccount.call(username: account.username, role_name:)
      end
    end
  end
end
