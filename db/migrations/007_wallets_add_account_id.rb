# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    next if schema(:wallets).any? { |name, _| name == :account_id }

    alter_table(:wallets) do
      add_foreign_key :account_id, :accounts, type: :uuid, null: true, on_delete: :cascade
    end
  end

  down do
    next unless schema(:wallets).any? { |name, _| name == :account_id }

    alter_table(:wallets) do
      drop_column :account_id
    end
  end
end
