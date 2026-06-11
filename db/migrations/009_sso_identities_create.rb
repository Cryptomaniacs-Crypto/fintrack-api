# frozen_string_literal: true

require 'sequel'

# Additive migration: an SSO identity is keyed on (provider, external_id) -- NOT
# email -- so one account can link several providers and a later email change
# never breaks the linkage. Google ships first; another provider needs only a new
# verifier + mapper, no schema change.
Sequel.migration do
  change do
    create_table(:sso_identities) do
      primary_key :id
      foreign_key :account_id, :accounts, type: :uuid, null: false

      String :provider, null: false
      String :external_id, null: false

      DateTime :created_at
      DateTime :updated_at

      unique %i[provider external_id]
      unique %i[account_id provider]
    end
  end
end
