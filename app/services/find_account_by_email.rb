# frozen_string_literal: true

module FinanceTracker
  # Finds an account by plaintext email through the lookup hash.
  class FindAccountByEmail
    def self.call(email:)
      Account.first(email_hash: SecureDB.hash(email))
    end
  end
end
