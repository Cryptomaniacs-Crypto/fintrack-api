# frozen_string_literal: true

require 'json'
require 'sequel'

module FinanceTracker
  # Models a named system role (admin or member).
  class Role < Sequel::Model
    class UnknownRoleError < StandardError; end

    many_to_many :accounts, join_table: :accounts_roles
    plugin :association_dependencies, accounts: :nullify
    plugin :timestamps, update_on_create: true

    # Convenience lookup — raises UnknownRoleError rather than returning nil.
    def self.id_for(name)
      first(name: name.to_s)&.id or raise UnknownRoleError, "Unknown role: #{name}"
    end

    # System-role predicates
    def admin?  = name == 'admin'
    def member? = name == 'member'

    # Grouping predicate
    def system? = %w[admin member].include?(name)

    def to_json(options = {})
      JSON({ id:, name: }, options)
    end
  end
end
