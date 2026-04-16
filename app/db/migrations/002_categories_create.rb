# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:categories) do
      primary_key :id

      String :name, null: false, unique: true

      DateTime :created_at
      DateTime :updated_at
    end
  end
end

# Sequel.migration do
#   change do
#     create_table(:categories) do
#       primary_key :id

#       foreign_key :transaction_id, :transactions, null: false, on_delete: :cascade
#       foreign_key :account_id, :accounts, null: true, on_delete: :set_null  # <-- change nullify to set_null

#       String :name, null: false, unique: true
#       String :description

#       DateTime :created_at
#       DateTime :updated_at
#     end
#   end
# end