# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:split_agreements) do
      uuid :id, primary_key: true

      foreign_key :initiator_account_id, :accounts, type: :uuid, null: false, on_delete: :cascade
      String :initiator_username, null: false
      String :participants_json, text: true, null: false
      String :tax_percent, null: false, default: '0.0'
      String :service_percent, null: false, default: '0.0'
      String :grand_total, null: false, default: '0.0'
      String :status, null: false, default: 'pending'
      String :dispute_reason
      DateTime :finalized_at

      DateTime :created_at
      DateTime :updated_at
    end
  end
end
