# frozen_string_literal: true

module FinanceTracker
  # Lists all system roles currently assigned to an account.
  class ListAccountRoles
    class AccountNotFoundError < StandardError; end

    def self.call(username:)
      account = Account.first(username:)
      raise AccountNotFoundError, 'Account not found' unless account

      account.system_roles
    end
  end
end
