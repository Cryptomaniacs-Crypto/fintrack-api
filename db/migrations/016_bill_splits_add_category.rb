# frozen_string_literal: true

Sequel.migration do
  up do
    # Column may already exist if a previous broken migration attempt ran the
    # ADD COLUMN SQL before failing at the Ruby level.
    run 'ALTER TABLE bill_splits ADD COLUMN IF NOT EXISTS category_id uuid'
    run <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.table_constraints
          WHERE constraint_name = 'bill_splits_category_id_fkey'
            AND table_name = 'bill_splits'
        ) THEN
          ALTER TABLE bill_splits
            ADD CONSTRAINT bill_splits_category_id_fkey
            FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL;
        END IF;
      END
      $$;
    SQL
  end

  down do
    alter_table(:bill_splits) do
      drop_foreign_key :category_id
      drop_column :category_id
    end
  end
end
