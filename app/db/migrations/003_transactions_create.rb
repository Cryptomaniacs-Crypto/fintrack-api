# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:transactions) do
      uuid :id, primary_key: true

      foreign_key :account_id, :accounts, type: :uuid, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, null: true, on_delete: :set_null

      String :title, null: false
      Numeric :amount, size: [12, 2], null: false
      Date :transaction_date, null: false
      String :note

      DateTime :created_at
      DateTime :updated_at
    end
  end
end