# frozen_string_literal: true

require 'http'

module FinanceTracker
  # Sends a payment reminder email to each non-owner participant who has not yet
  # paid their share of a sent bill split, provided at least 3 days have passed
  # since the bill was sent (or since the last reminder). Safe to call daily —
  # the 3-day gate is enforced here, not in the scheduler.
  class RemindBillSplit
    THREE_DAYS_SECS = 3 * 24 * 60 * 60

    def self.call
      new.call
    end

    def call
      return if api_key.to_s.strip.empty?

      due_participants.each do |participant|
        send_reminder(participant)
        participant.this.update(reminded_at: Time.now.utc)
      rescue StandardError => e
        Api.logger.error("RemindBillSplit: failed for participant #{participant.id}: #{e.message}")
      end
    end

    private

    def due_participants
      cutoff = Time.now.utc - THREE_DAYS_SECS
      BillSplitParticipant
        .where(status: %w[pending agreed])
        .where(bill_split_id: BillSplit.where(status: %w[pending disputed]).select(:id))
        .where(Sequel.lit('(reminded_at IS NULL OR reminded_at < ?)', cutoff))
        .all
        .reject { |p| p.bill_split.creator_id == p.account_id }
    end

    def send_reminder(participant)
      account = participant.account
      return unless account

      to_email = account.email
      return if to_email.to_s.strip.empty?

      bill   = participant.bill_split
      row    = bill.breakdown.find { |r| r[:account_id] == participant.account_id }
      amount = row ? row[:total] : '?'

      owner_wallets = Wallet.where(account_id: bill.creator_id).all
      payment_lines = owner_wallets.map { |w| "  • #{w.name} (#{w.method_type.to_s.tr('_', ' ')})" }
      payment_info  = payment_lines.empty? ? '  Contact the bill owner directly for payment details.' : payment_lines.join("\n")

      app_url   = ENV.fetch('APP_URL', '').chomp('/')
      bill_link = app_url.empty? ? '' : "\nView and respond here:\n#{app_url}/bill-splits/#{bill.id}\n"

      response = HTTP
                   .auth("Bearer #{api_key}")
                   .post(mail_url, json: mail_json(account, bill, amount, payment_info, bill_link))
      return if response.status < 300

      Api.logger.error("SendGrid reminder error #{response.status}: #{response.body}")
    end

    def mail_json(account, bill, amount, payment_info, bill_link)
      {
        personalizations: [{ to: [{ email: account.email }] }],
        from:    { email: from_email, name: from_name },
        subject: "Reminder: pay your share for '#{bill.title}'",
        content: [{
          type:  'text/plain',
          value: <<~TEXT
            Hi #{account.username},

            This is a friendly reminder that you have an unpaid share in a bill split from #{bill.creator&.username}.

            Bill:       #{bill.title}
            Your share: $#{amount}

            You can pay to any of the owner's payment methods:
            #{payment_info}

            Or arrange another payment method with #{bill.creator&.username} directly.
            #{bill_link}
            — Fintrack
          TEXT
        }]
      }
    end

    def api_key    = ENV.fetch('SENDGRID_API_KEY', nil)
    def mail_url   = 'https://api.sendgrid.com/v3/mail/send'
    def from_email = ENV.fetch('SENDGRID_FROM_EMAIL', nil)
    def from_name  = ENV.fetch('SENDGRID_FROM_NAME', 'Fintrack')
  end
end
