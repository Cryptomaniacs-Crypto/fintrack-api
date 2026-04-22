# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models an account entry linked to a transaction
  class Account < Sequel::Model
    one_to_many :transactions
    plugin :association_dependencies, transactions: :nullify

    plugin :timestamps

    # rubocop:disable Metrics/MethodLength
    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'account',
            attributes: {
              id:,
              name:,
              account_number: account_number
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
