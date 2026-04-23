# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:accounts) do
      uuid :id, primary_key: true

      String :name, null: false
      String :account_number_secure
      String :balance_secure, null: false
      
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
