# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a financial transaction
  class Transaction < Sequel::Model
    many_to_one :account
    many_to_one :category

    plugin :timestamps

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
