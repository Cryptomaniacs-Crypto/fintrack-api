# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a category entry linked to an account and transaction
  class Category < Sequel::Model
    many_to_one :account
    many_to_one :transaction
    plugin :association_dependencies

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
            account:,
            transaction:
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end