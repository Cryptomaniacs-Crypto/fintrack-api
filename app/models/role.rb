# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a named system role (admin, member, etc.).
  class Role < Sequel::Model
    many_to_many :accounts, join_table: :accounts_roles
    plugin :association_dependencies, accounts: :nullify

    plugin :timestamps, update_on_create: true

    def to_json(options = {})
      JSON({ id:, name: }, options)
    end
  end
end
