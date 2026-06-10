# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :bill_split_participants, :reminded_at, DateTime
  end
end
