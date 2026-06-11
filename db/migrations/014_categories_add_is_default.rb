# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    add_column :categories, :is_default, :boolean, default: false

    # Mark the two system-seeded categories
    from(:categories).where(name: %w[Food Entertainment]).update(is_default: true)
  end

  down do
    drop_column :categories, :is_default
  end
end
