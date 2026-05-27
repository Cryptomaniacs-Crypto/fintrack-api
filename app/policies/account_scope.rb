# frozen_string_literal: true

module FinanceTracker
  class AccountScope
    def initialize(viewer)
      @viewer = viewer
    end

    def viewable
      return Account.where(Sequel.lit('1 = 0')) unless @viewer
      return Account.all if AccountPolicy.new(@viewer).is_admin?

      Account.where(id: @viewer.id)
    end
  end
end
