# frozen_string_literal: true

module FinanceTracker
  # Creates an account from request payload data.
  class CreateAccount
    class CouldNotPersistAccountError < StandardError; end

    def self.call(account_data:)
      account = Account.new(account_data)
      raise CouldNotPersistAccountError, 'Could not save account' unless account.save_changes

      account
    end
  end
end
