# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    drop_table?(:split_agreements)

    create_table(:bill_splits) do
      uuid :id, primary_key: true

      foreign_key :creator_id, :accounts, type: :uuid, null: false, on_delete: :cascade
      foreign_key :recipient_id, :accounts, type: :uuid, null: false, on_delete: :cascade

      # Stored as string for exact decimal representation (no float imprecision)
      String :amount, null: false

      # reason_note and dispute_note are encrypted at rest via SecureDB
      String :reason_note_secure, text: true, null: false
      String :dispute_note_secure, text: true

      String :status, null: false, default: 'pending'
      DateTime :recipient_agreed_at
      DateTime :settled_at

      DateTime :created_at
      DateTime :updated_at
    end
  end

  down do
    drop_table?(:bill_splits)
  end
end
