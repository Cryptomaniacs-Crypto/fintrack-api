# frozen_string_literal: true

module FinanceTracker
  class AccountPolicy
    def initialize(viewer, target = viewer)
      @viewer = viewer
      @target = target
    end

    def is_admin?
      role_names.include?('admin')
    end

    def can_manage_system_roles?
      is_admin?
    end

    def can_create_wallet?
      @viewer ? true : false
    end

    def can_create_transaction?
      @viewer ? true : false
    end

    def can_view?
      viewer_is_self? || is_admin?
    end

    def can_edit?
      viewer_is_self? || is_admin?
    end

    def can_delete?
      is_admin? && !viewer_is_self?
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

    def viewer_is_self?
      @viewer && @target && @viewer.id == @target.id
    end

    def role_names
      Array(@viewer&.system_roles).map(&:name)
    end
  end
end
