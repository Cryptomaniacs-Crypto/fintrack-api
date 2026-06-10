# frozen_string_literal: true

Sequel.migration do
  up do
    # A previous failed attempt may have added category_id as uuid (wrong type).
    # Drop it if present so we can add it with the correct integer type.
    run 'ALTER TABLE bill_splits DROP COLUMN IF EXISTS category_id'
    alter_table(:bill_splits) do
      add_column :category_id, Integer, null: true
      add_foreign_key :category_id, :categories, null: true, on_delete: :set_null
    end
  end

  down do
    alter_table(:bill_splits) do
      drop_foreign_key :category_id
      drop_column :category_id
    end
  end
end
