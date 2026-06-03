# frozen_string_literal: true

require_relative '../lib/auth_scope'

module FinanceTracker
  class WalletPolicy
    RESOURCE = 'wallets'

    def initialize(account, wallet, auth_scope: AuthScope.new)
      @account = account
      @wallet = wallet
      @auth_scope = auth_scope
    end

    def can_view?
      can_read? && (account_is_owner? || account_is_admin?)
    end

    def can_edit?
      can_write? && (account_is_owner? || account_is_admin?)
    end

    def can_delete?
      can_edit?
    end

    def summary
      {
        can_view: can_view?,
        can_edit: can_edit?,
        can_delete: can_delete?
      }
    end

    def index_summary
      { can_view: can_view?, can_edit: can_edit? }
    end

    private

    def can_read?
      @auth_scope.can_read?(RESOURCE)
    end

    def can_write?
      @auth_scope.can_write?(RESOURCE)
    end

    def account_is_owner?
      @account && @wallet && @wallet.account_id && @wallet.account_id == @account.id
    end

    def account_is_admin?
      AccountPolicy.new(@account).is_admin?
    end
  end
end
