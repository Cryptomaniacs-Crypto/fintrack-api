# frozen_string_literal: true

module FinanceTracker
  class WalletPolicy
    def initialize(account, wallet)
      @account = account
      @wallet = wallet
    end

    def can_view?
      account_is_owner? || account_is_admin?
    end

    def can_edit?
      can_view?
    end

    def can_delete?
      can_view?
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

    def account_is_owner?
      @account && @wallet && @wallet.account_id && @wallet.account_id == @account.id
    end

    def account_is_admin?
      AccountPolicy.new(@account).is_admin?
    end
  end
end
