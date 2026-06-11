# frozen_string_literal: true

require 'sequel'

# Additive migration: a friendship is a one-way contact list entry. `account_id`
# is the owner who saved the contact; `friend_id` is the saved account. It is
# directional (no acceptance/status) and not auto-reciprocal -- adding someone
# only puts them on *your* list. The unique pair stops duplicate saves.
Sequel.migration do
  change do
    create_table(:friendships) do
      primary_key :id
      foreign_key :account_id, :accounts, type: :uuid, null: false
      foreign_key :friend_id, :accounts, type: :uuid, null: false

      DateTime :created_at
      DateTime :updated_at

      unique %i[account_id friend_id]
    end
  end
end
