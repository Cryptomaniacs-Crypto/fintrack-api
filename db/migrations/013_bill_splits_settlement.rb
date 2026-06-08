# frozen_string_literal: true

require 'sequel'

# Phase 2: tie bill-split settlement to real wallet transactions plus optional
# payment-proof images.
#
# - The owner records an upfront expense (they fronted the bill) when sending:
#   creator_wallet_id + outlay_transaction_id.
# - Each participant marks "I paid" against one of THEIR wallets (an expense),
#   optionally attaching an encrypted proof image; the owner then confirms,
#   recording an income on one of the owner's wallets.
#
# *_transaction_id / *_wallet_id are plain uuid references (no FK) so deleting a
# wallet or transaction never cascades into bill-split rows; the app manages
# these links explicitly.
Sequel.migration do
  change do
    alter_table(:bill_splits) do
      add_column :creator_wallet_id, :uuid          # wallet the owner fronted from
      add_column :outlay_transaction_id, :uuid       # the upfront expense transaction
    end

    alter_table(:bill_split_participants) do
      add_column :paid_at, DateTime
      add_column :paid_wallet_id, :uuid              # payer's wallet (expense)
      add_column :expense_transaction_id, :uuid      # payer-side expense
      add_column :received_wallet_id, :uuid          # owner's wallet (income)
      add_column :income_transaction_id, :uuid       # owner-side income
      add_column :proof_image_secure, String, text: true  # encrypted base64 image
      add_column :proof_content_type, String         # e.g. image/png
    end
  end
end
