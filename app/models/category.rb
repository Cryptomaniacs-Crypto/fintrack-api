# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a transaction category
  class Category < Sequel::Model
    one_to_many :transactions
    plugin :association_dependencies, transactions: :nullify
    plugin :timestamps

    # rubocop:disable Metrics/MethodLength
    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'category',
            attributes: {
              id:,
              name:,
              description:
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
