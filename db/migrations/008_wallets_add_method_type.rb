# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    alter_table(:wallets) do
      add_column :method_type, String, null: false, default: 'cash'
      add_index :account_id
    end
  end
end
