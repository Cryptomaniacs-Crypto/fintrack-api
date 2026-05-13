# frozen_string_literal: true

require 'json'
require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # Models a financial wallet (e.g., cash wallet, bank account)
  class Wallet < Sequel::Model
    one_to_many :transactions
    plugin :association_dependencies, transactions: :nullify

    plugin :uuid, field: :id
    plugin :timestamps
    plugin :whitelist_security
    set_allowed_columns :name

    class << self
      def create(values = nil, &block)
        return super unless values.is_a?(Hash)

        secure_values = {}
        regular_values = values.dup

        if regular_values.key?(:account_number)
          secure_values[:account_number] = regular_values.delete(:account_number)
        elsif regular_values.key?('account_number')
          secure_values[:account_number] = regular_values.delete('account_number')
        end
        if regular_values.key?(:balance)
          secure_values[:balance] = regular_values.delete(:balance)
        elsif regular_values.key?('balance')
          secure_values[:balance] = regular_values.delete('balance')
        end

        wallet = new(regular_values, &block)
        secure_values.each { |key, value| wallet.public_send("#{key}=", value) unless value.nil? }
        wallet.save
        wallet
      end
    end

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
            type: 'wallet',
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
