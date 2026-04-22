# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id

      String :name, null: false
      String  :account_number
      Numeric :balance, size: [12, 2], null: false, default: 0
      
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
