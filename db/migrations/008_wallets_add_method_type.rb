# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    columns = schema(:wallets).map(&:first)

    alter_table(:wallets) do
      add_column :method_type, String, null: false, default: 'cash' unless columns.include?(:method_type)
    end

    add_index :wallets, :account_id unless indexes(:wallets).key?(:wallets_account_id_index)
  end

  down do
    columns = schema(:wallets).map(&:first)

    drop_index :wallets, :account_id if indexes(:wallets).key?(:wallets_account_id_index)

    alter_table(:wallets) do
      drop_column :method_type if columns.include?(:method_type)
    end
  end
end
