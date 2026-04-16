# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a transaction category
  class Category < Sequel::Model
    many_to_one :transaction
    many_to_one :account

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
            transaction:,
            account:
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
