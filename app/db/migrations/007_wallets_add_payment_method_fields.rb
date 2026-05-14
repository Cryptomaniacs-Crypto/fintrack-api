# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    alter_table(:wallets) do
      add_foreign_key :account_id, :accounts, type: :uuid, null: true, on_delete: :cascade
      add_column :method_type, String, null: false, default: 'cash'
      add_index :account_id
    end
  end
end
