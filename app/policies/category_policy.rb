# frozen_string_literal: true

module FinanceTracker
  class CategoryPolicy
    def initialize(account, category)
      @account = account
      @category = category
    end

    def can_view?
      !!@account
    end

    def can_edit?
      AccountPolicy.new(@account).is_admin?
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
  end
end
