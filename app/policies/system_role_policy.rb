# frozen_string_literal: true

module FinanceTracker
  class SystemRolePolicy
    def initialize(viewer, target_account)
      @viewer = viewer
      @target_account = target_account
    end

    def can_manage?
      return false unless @viewer && @target_account

      AccountPolicy.new(@viewer, @target_account).can_manage_system_roles?
    end

    def summary
      { can_manage: can_manage? }
    end
  end
end
