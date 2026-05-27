# frozen_string_literal: true

module FinanceTracker
  class TransactionPolicy
    def initialize(account, transaction)
      @account = account
      @transaction = transaction
    end

    def can_view?
      account_owns_wallet? || account_is_admin?
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

    def account_owns_wallet?
      return false unless @account && @transaction&.wallet

      @transaction.wallet.account_id == @account.id
    end

    def account_is_admin?
      AccountPolicy.new(@account).is_admin?
    end
  end
end
