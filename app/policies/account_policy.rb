# frozen_string_literal: true

require_relative '../lib/auth_scope'

module FinanceTracker
  class AccountPolicy
    RESOURCE = 'accounts'

    def initialize(viewer, target = viewer, auth_scope: AuthScope.new)
      @viewer = viewer
      @target = target
      @auth_scope = auth_scope
    end

    # Identity fact, independent of the token's scope: a read-only key still
    # belongs to an admin, it just cannot perform writes.
    def is_admin?
      role_names.include?('admin')
    end

    def can_manage_system_roles?
      can_write? && is_admin?
    end

    def can_create_wallet?
      can_write?('wallets') && !@viewer.nil?
    end

    def can_create_transaction?
      can_write?('transactions') && !@viewer.nil?
    end

    def can_view?
      can_read? && (viewer_is_self? || is_admin?)
    end

    def can_edit?
      can_write? && (viewer_is_self? || is_admin?)
    end

    def can_delete?
      can_write? && is_admin? && !viewer_is_self?
    end

    def can_assign_role?
      can_manage_system_roles?
    end

    def can_revoke_role?
      can_manage_system_roles?
    end

    def summary
      {
        can_view: can_view?,
        can_edit: can_edit?,
        can_delete: can_delete?,
        can_assign_role: can_assign_role?,
        can_revoke_role: can_revoke_role?
      }
    end

    def index_summary
      {
        can_view: can_view?,
        can_edit: can_edit?,
        can_assign_role: can_assign_role?
      }
    end

    def capabilities
      {
        is_admin: is_admin?,
        can_manage_system_roles: can_manage_system_roles?,
        can_create_wallet: can_create_wallet?,
        can_create_transaction: can_create_transaction?
      }
    end

    private

    def can_read?(resource = RESOURCE)
      @auth_scope.can_read?(resource)
    end

    def can_write?(resource = RESOURCE)
      @auth_scope.can_write?(resource)
    end

    def viewer_is_self?
      @viewer && @target && @viewer.id == @target.id
    end

    def role_names
      Array(@viewer&.system_roles).map(&:name)
    end
  end
end
