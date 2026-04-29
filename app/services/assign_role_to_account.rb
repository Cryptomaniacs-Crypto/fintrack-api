# frozen_string_literal: true

module FinanceTracker
  # Assigns a system role to an account.
  class AssignRoleToAccount
    class AccountNotFoundError < StandardError; end
    class RoleNotFoundError < StandardError; end
    class RoleAlreadyAssignedError < StandardError; end

    def self.call(username:, role_name:)
      account = Account.first(username:)
      raise AccountNotFoundError, 'Account not found' unless account

      role = Role.first(name: role_name)
      raise RoleNotFoundError, 'Role not found' unless role

      if account.system_roles_dataset.where(id: role.id).first
        raise RoleAlreadyAssignedError, 'Role already assigned'
      end

      account.add_system_role(role)
      role
    end
  end
end
