# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:bill_splits) do
      add_column :category_id, :uuid, null: true
      add_foreign_key :category_id, :categories, type: :uuid, null: true, on_delete: :set_null
    end
  end

  down do
    alter_table(:bill_splits) do
      drop_foreign_key :category_id
      drop_column :category_id
    end
  end
end
