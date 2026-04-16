# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models an account entry linked to a transaction
  class Account < Sequel::Model
    many_to_one :transaction
    one_to_many :categories
    plugin :association_dependencies, categories: :nullify

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
              amount:,
              description:
            }
          },
          included: {
            transaction:
          }
        }, options
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
