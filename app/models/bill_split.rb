# frozen_string_literal: true

require 'json'
require 'sequel'
require_relative '../lib/secure_db'

module FinanceTracker
  # Tracks a two-party bill split between a creator and a recipient.
  # reason_note and dispute_note are encrypted at rest via SecureDB.
  class BillSplit < Sequel::Model
    many_to_one :creator, class: :'FinanceTracker::Account', key: :creator_id
    many_to_one :recipient, class: :'FinanceTracker::Account', key: :recipient_id

    plugin :uuid, field: :id
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :creator_id, :recipient_id, :amount,
                        :reason_note_secure, :dispute_note_secure,
                        :status, :recipient_agreed_at, :settled_at

    # reason_note is sensitive: stored encrypted, exposed as plaintext virtual attr.
    def reason_note
      SecureDB.decrypt(reason_note_secure)
    end

    def reason_note=(plaintext)
      self.reason_note_secure = SecureDB.encrypt(plaintext.to_s.strip)
    end

    # dispute_note is sensitive: stored encrypted when present.
    def dispute_note
      SecureDB.decrypt(dispute_note_secure)
    end

    def dispute_note=(plaintext)
      stripped = plaintext.to_s.strip
      self.dispute_note_secure = stripped.empty? ? nil : SecureDB.encrypt(stripped)
    end

    # Authorization predicates — used by controllers and policies.
    def creator?(account)
      account&.id == creator_id
    end

    def recipient?(account)
      account&.id == recipient_id
    end

    def participant?(account)
      creator?(account) || recipient?(account)
    end

    # Status predicates
    def pending? = status == 'pending'
    def agreed?  = status == 'agreed'
    def settled? = status == 'settled'

    # Recipient agrees to the amount. Status moves to 'agreed'.
    def agree!
      raise 'Bill split is already settled' if settled?

      update(status: 'agreed', recipient_agreed_at: Time.now.utc)
      self
    end

    # Recipient raises a dispute. Status stays 'pending'; creator may revise.
    def dispute!(reason)
      raise 'Bill split is already settled' if settled?
      raise 'Dispute reason is required' if reason.to_s.strip.empty?

      self.dispute_note = reason
      save_changes
      self
    end

    # Either party marks the split settled after out-of-app payment.
    # Settled records become read-only.
    def settle!
      raise 'Bill split is already settled' if settled?

      update(status: 'settled', settled_at: Time.now.utc)
      self
    end

    def to_h
      {
        id: id,
        creator_id: creator_id,
        creator_username: creator&.username,
        recipient_id: recipient_id,
        recipient_username: recipient&.username,
        amount: amount,
        reason_note: reason_note,
        dispute_note: dispute_note,
        status: status,
        recipient_agreed_at: recipient_agreed_at,
        settled_at: settled_at,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'bill_split',
            attributes: to_h
          }
        }, options
      )
    end
  end
end
