# frozen_string_literal: true

require 'json'
require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # Models a financial transaction
  class Transaction < Sequel::Model
    many_to_one :account
    many_to_one :category

    plugin :uuid, field: :id
    plugin :timestamps
    plugin :whitelist_security
    set_allowed_columns :title, :transaction_date, :note, :account_id, :category_id

    class << self
      def create(values = nil, &block)
        return super unless values.is_a?(Hash)

        secure_values = {}
        regular_values = values.dup
        if regular_values.key?(:amount)
          secure_values[:amount] = regular_values.delete(:amount)
        elsif regular_values.key?('amount')
          secure_values[:amount] = regular_values.delete('amount')
        end

        transaction = new(regular_values, &block)
        transaction.amount = secure_values[:amount] if secure_values.key?(:amount) && !secure_values[:amount].nil?
        transaction.save
        transaction
      end
    end

    # Secure getter and setter
    def amount
      SecureDB.decrypt(amount_secure)
    end

    def amount=(plaintext)
      self.amount_secure = SecureDB.encrypt(plaintext)
    end

    # rubocop:disable Metrics/MethodLength
    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'transaction',
            attributes: {
              id:,
              title:,
              amount:,
              transaction_date:,
              note:
            }
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
