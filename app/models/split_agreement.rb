# frozen_string_literal: true

require 'json'
require 'sequel'
require 'time'

module FinanceTracker
  class SplitAgreement < Sequel::Model
    many_to_one :initiator_account,
                class: :'FinanceTracker::Account',
                key: :initiator_account_id

    plugin :uuid, field: :id
    plugin :timestamps
    plugin :whitelist_security
    set_allowed_columns :initiator_account_id, :initiator_username, :participants_json,
                        :tax_percent, :service_percent, :grand_total,
                        :status, :dispute_reason, :finalized_at

    def participants
      JSON.parse(participants_json.to_s)
    rescue JSON::ParserError
      []
    end

    def participants=(value)
      self.participants_json = JSON.generate(value)
    end

    def participant_usernames
      participants.map { |entry| entry['name'].to_s }.reject(&:empty?)
    end

    def participant?(username)
      participant_usernames.include?(username.to_s)
    end

    def mark_agreed!(username)
      update_participant(username) do |entry|
        entry['agreed'] = true
        entry['agreed_at'] = Time.now.utc.iso8601
      end
      self.status = 'agreed' if all_participants_agreed? && status == 'pending'
      save_changes
      self
    end

    def mark_paid!(username)
      update_participant(username) do |entry|
        entry['paid'] = true
        entry['paid_at'] = Time.now.utc.iso8601
      end
      self.status = 'paid' if all_participants_paid?
      save_changes
      self
    end

    def mark_disputed!(username, reason)
      update_participant(username) do |entry|
        entry['disputed'] = true
        entry['disputed_at'] = Time.now.utc.iso8601
      end
      self.dispute_reason = reason.to_s.strip
      self.status = 'disputed'
      save_changes
      self
    end

    def finalize!
      self.status = 'finalized'
      self.finalized_at = Time.now.utc
      save_changes
      self
    end

    def all_participants_agreed?
      participants.any? && participants.all? { |entry| entry['agreed'] == true }
    end

    def all_participants_paid?
      participants.any? && participants.all? { |entry| entry['paid'] == true }
    end

    def disputed?
      status == 'disputed' || participants.any? { |entry| entry['disputed'] == true }
    end

    def to_h
      {
        id: id,
        initiator_account_id: initiator_account_id,
        initiator_username: initiator_username,
        tax_percent: tax_percent,
        service_percent: service_percent,
        grand_total: grand_total,
        status: status,
        dispute_reason: dispute_reason,
        finalized_at: finalized_at,
        participants: participants,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'split_agreement',
            attributes: to_h
          }
        }, options
      )
    end

    private

    def update_participant(username)
      username = username.to_s
      rows = participants
      index = rows.find_index { |entry| entry['name'].to_s == username }
      raise StandardError, 'Participant not found in agreement' unless index

      yield rows[index]
      self.participants = rows
    end
  end
end
