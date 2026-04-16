# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id

      String :name, null: false
      Float :balance, null: false, default: 0.0
      
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
