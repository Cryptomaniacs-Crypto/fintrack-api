# frozen_string_literal: true

require 'json'
require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # Models an account entry linked to a transaction
  class Account < Sequel::Model
    one_to_many :transactions
    plugin :association_dependencies, transactions: :nullify

    plugin :timestamps

    # Secure getters and setters
    def account_number
      SecureDB.decrypt(account_number_secure)
    end

    def account_number=(plaintext)
      self.account_number_secure = SecureDB.encrypt(plaintext)
    end

    def balance
      SecureDB.decrypt(balance_secure)
    end

    def balance=(plaintext)
      self.balance_secure = SecureDB.encrypt(plaintext)
    end

    # rubocop:disable Metrics/MethodLength
    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'account',
            attributes: {
              id:,
              name:,
              account_number:,
              balance:
            }
          },
          included: {
            transactions:
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
