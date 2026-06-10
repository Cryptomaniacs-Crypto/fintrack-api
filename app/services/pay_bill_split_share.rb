# frozen_string_literal: true

require 'date'
require_relative '../lib/image_proof'

module FinanceTracker
  # A participant marks their share paid: records an expense on one of THEIR
  # wallets and (optionally) attaches an encrypted proof image. Status -> paid,
  # awaiting the owner's confirmation.
  class PayBillSplitShare
    class InvalidInput < StandardError; end
    class NotAllowed < StandardError; end

    def self.call(bill:, payer:, wallet_id:, proof_base64: nil, proof_content_type: nil)
      participant = bill.participant_for(payer)
      raise NotAllowed, 'You are not a participant on this bill' unless participant
      raise NotAllowed, 'The owner does not pay their own share' if participant.account_id == bill.creator_id
      raise InvalidInput, 'This bill split is not open for payment' unless bill.pending?
      raise InvalidInput, 'Agree to your share before paying' unless participant.agreed?

      wallet = WalletOwnership.owned!(payer, wallet_id, InvalidInput)
      content_type = validate_proof(proof_base64, proof_content_type)

      FinanceTracker::Api.DB.transaction do
        tx = FinanceTracker::Transaction.create(
          title: "Bill split: #{bill.title} (your share)",
          amount: "-#{bill.total_for(participant)}",
          transaction_date: Date.today,
          wallet_id: wallet.id,
          category_id: bill.category_id
        )
        participant.status = 'paid'
        participant.paid_at = Time.now.utc
        participant.paid_wallet_id = wallet.id
        participant.expense_transaction_id = tx.id
        unless proof_base64.to_s.empty?
          participant.proof_image = proof_base64
          participant.proof_content_type = content_type
        end
        participant.save_changes
        bill.reload
      end
    end

    def self.validate_proof(base64, content_type)
      return nil if base64.to_s.empty?

      FinanceTracker::ImageProof.validate!(base64, content_type)
    rescue FinanceTracker::ImageProof::InvalidImage => e
      raise InvalidInput, e.message
    end
  end
end
