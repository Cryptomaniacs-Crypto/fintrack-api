# frozen_string_literal: true

require_relative '../lib/auth_scope'

module FinanceTracker
  class SystemRolePolicy
    def initialize(viewer, target_account, auth_scope: AuthScope.new)
      @viewer = viewer
      @target_account = target_account
      @auth_scope = auth_scope
    end

    # Managing system roles is a write on the accounts resource, so the token
    # scope is threaded into AccountPolicy: a READ_ONLY key can never assign or
    # revoke roles even for an admin account.
    def can_manage?
      return false unless @viewer && @target_account

      AccountPolicy.new(@viewer, @target_account, auth_scope: @auth_scope).can_manage_system_roles?
    end

    def summary
      { can_manage: can_manage? }
    end
  end
end
