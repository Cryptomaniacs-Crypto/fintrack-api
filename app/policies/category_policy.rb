# frozen_string_literal: true

require_relative '../lib/auth_scope'

module FinanceTracker
  class CategoryPolicy
    RESOURCE = 'categories'

    def initialize(account, category, auth_scope: AuthScope.new)
      @account = account
      @category = category
      @auth_scope = auth_scope
    end

    def can_view?
      can_read? && !@account.nil?
    end

    def can_edit?
      can_write? && !@account.nil?
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
      { can_view: can_view?, can_edit: can_edit?, can_delete: can_delete? }
    end

    private

    def can_read?
      @auth_scope.can_read?(RESOURCE)
    end

    def can_write?
      @auth_scope.can_write?(RESOURCE)
    end
  end
end
