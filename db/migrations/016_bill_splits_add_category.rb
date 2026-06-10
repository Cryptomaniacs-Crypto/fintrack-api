# frozen_string_literal: true

Sequel.migration do
  up do
    # Previous failed attempts may have left a category_id column with the wrong
    # type (uuid instead of integer). Drop and recreate cleanly via raw SQL.
    run 'ALTER TABLE bill_splits DROP COLUMN IF EXISTS category_id CASCADE'
    run 'ALTER TABLE bill_splits ADD COLUMN category_id integer'
    run <<~SQL
      ALTER TABLE bill_splits
        ADD CONSTRAINT bill_splits_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
    SQL
  end

  down do
    run 'ALTER TABLE bill_splits DROP COLUMN IF EXISTS category_id CASCADE'
  end
end
