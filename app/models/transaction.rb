# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a financial transaction
  class Transaction < Sequel::Model
    one_to_many :accounts
    one_to_many :categories
    plugin :association_dependencies,
           accounts: :destroy,
           categories: :destroy

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
              transaction_date:
            }
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
