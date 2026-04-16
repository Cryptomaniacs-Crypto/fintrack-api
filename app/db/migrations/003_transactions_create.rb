# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:transactions) do
      primary_key :id

      foreign_key :account_id, :accounts, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, null: false, on_delete: :cascade

      String :title, null: false
      Float :amount, null: false
      Date :transaction_date, null: false
      String :note

      DateTime :created_at
      DateTime :updated_at
    end
  end
end


# Sequel.migration do
#   change do
#     create_table(:transactions) do
#       primary_key :id

#       String :title, null: false
#       Float :amount, null: false
#       Date :transaction_date, null: false
#       String :note

#       DateTime :created_at
#       DateTime :updated_at
#     end
#   end
# end