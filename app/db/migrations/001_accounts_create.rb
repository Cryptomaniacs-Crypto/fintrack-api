# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:accounts) do
      primary_key :id

      String :name, null: false

      DateTime :created_at
      DateTime :updated_at
    end
  end
end


# Sequel.migration do
#   change do
#     create_table(:accounts) do
#       primary_key :id

#       foreign_key :transaction_id, :transactions, null: false, on_delete: :cascade

#       String :name, null: false
#       Float :amount
#       String :description

#       DateTime :created_at
#       DateTime :updated_at
#     end
#   end
# end