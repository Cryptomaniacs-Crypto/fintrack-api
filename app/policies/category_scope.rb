# frozen_string_literal: true

module FinanceTracker
  class CategoryScope
    def initialize(account)
      @account = account
    end

    def viewable
      return Category.where(Sequel.lit('1 = 0')) unless @account

      Category.all
    end
  end
end
