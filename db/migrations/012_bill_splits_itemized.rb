# frozen_string_literal: true

require 'sequel'

# Phase 1 of itemized, multi-person bill splits. Replaces the two-party
# bill_splits (one creator owes one recipient a single amount) with a bill that
# has many participants and many dishes (items). Each dish is shared by a subset
# of participants and split equally among its sharers; tax and service are
# bill-wide percentages applied proportionally to each person's subtotal.
#
# Money movement (wallet debits/credits + payment proof) lands in a later
# migration -- this phase only models who-owes-what.
Sequel.migration do
  up do
    drop_table?(:bill_splits)

    create_table(:bill_splits) do
      uuid :id, primary_key: true
      foreign_key :creator_id, :accounts, type: :uuid, null: false, on_delete: :cascade

      String :title, null: false
      # Optional free-text note, encrypted at rest via SecureDB.
      String :note_secure, text: true
      # Stored as strings for exact decimal representation (no float drift).
      String :tax_percent, null: false, default: '0.0'
      String :service_percent, null: false, default: '0.0'
      # draft -> pending (sent) -> disputed (a rejection) -> settled
      String :status, null: false, default: 'draft'

      DateTime :sent_at
      DateTime :settled_at
      DateTime :created_at
      DateTime :updated_at
    end

    create_table(:bill_split_participants) do
      uuid :id, primary_key: true
      foreign_key :bill_split_id, :bill_splits, type: :uuid, null: false, on_delete: :cascade
      foreign_key :account_id, :accounts, type: :uuid, null: false, on_delete: :cascade

      # pending -> agreed | rejected ; settled in a later phase
      String :status, null: false, default: 'pending'
      # Reject reason, encrypted when present.
      String :reject_note_secure, text: true
      DateTime :agreed_at
      DateTime :rejected_at
      DateTime :settled_at
      DateTime :created_at
      DateTime :updated_at

      # One participant row per (bill, account).
      unique %i[bill_split_id account_id]
    end

    create_table(:bill_split_items) do
      uuid :id, primary_key: true
      foreign_key :bill_split_id, :bill_splits, type: :uuid, null: false, on_delete: :cascade

      String :name, null: false
      # Exact decimal as a string, consistent with bill-wide percentages.
      String :amount, null: false

      DateTime :created_at
      DateTime :updated_at
    end

    # Join: which participants share a given dish (split equally among them).
    create_table(:bill_split_item_shares) do
      foreign_key :bill_split_item_id, :bill_split_items, type: :uuid, null: false, on_delete: :cascade
      foreign_key :bill_split_participant_id, :bill_split_participants, type: :uuid, null: false, on_delete: :cascade
      primary_key %i[bill_split_item_id bill_split_participant_id]
      index %i[bill_split_participant_id bill_split_item_id]
    end
  end

  down do
    drop_table?(:bill_split_item_shares)
    drop_table?(:bill_split_items)
    drop_table?(:bill_split_participants)
    drop_table?(:bill_splits)
  end
end
