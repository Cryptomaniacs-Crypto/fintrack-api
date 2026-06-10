# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :bill_splits, :category_id, :uuid
    add_foreign_key [:category_id], :categories, on_delete: :set_null
  end
end
