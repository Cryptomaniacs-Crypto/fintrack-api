# frozen_string_literal: true

Sequel.migration do
  up do
    # Add bill_splits.category_id as an integer FK to categories.
    # Postgres (prod) needs the raw drop+constraint dance because earlier failed
    # attempts may have left a wrongly-typed (uuid) column behind. SQLite (local
    # tests) has no such history and can't parse that SQL, so it gets the plain
    # portable form -- keeping the whole spec suite runnable without Postgres.
    if database_type == :postgres
      run 'ALTER TABLE bill_splits DROP COLUMN IF EXISTS category_id CASCADE'
      run 'ALTER TABLE bill_splits ADD COLUMN category_id integer'
      run <<~SQL
        ALTER TABLE bill_splits
          ADD CONSTRAINT bill_splits_category_id_fkey
          FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      SQL
    else
      alter_table(:bill_splits) do
        add_foreign_key :category_id, :categories, type: :integer, on_delete: :set_null
      end
    end
  end

  down do
    if database_type == :postgres
      run 'ALTER TABLE bill_splits DROP COLUMN IF EXISTS category_id CASCADE'
    else
      alter_table(:bill_splits) { drop_column :category_id }
    end
  end
end
