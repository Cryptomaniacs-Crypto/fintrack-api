# frozen_string_literal: true

require 'http'

module FinanceTracker
  # Emails each non-owner participant when a bill split is sent to them.
  # Credentials are read from SENDGRID_* ENV vars (set as Heroku config vars).
  # All errors are silenced so notification failures never abort the main flow.
  class NotifyBillSplit
    def self.call(bill:, app_url: nil)
      new(bill:, app_url:).call
    rescue StandardError
      nil
    end

    def initialize(bill:, app_url: nil)
      @bill    = bill
      @app_url = app_url.to_s.chomp('/')
    end

    def call
      return if api_key.to_s.strip.empty?

      @bill.non_creator_participants.each do |participant|
        send_notification(participant)
      rescue StandardError
        next
      end
    end

    private

    def send_notification(participant)
      account = participant.account
      return unless account

      to_email = account.email
      return if to_email.to_s.strip.empty?

      response = HTTP
                 .auth("Bearer #{api_key}")
                 .post(mail_url, json: mail_json(participant, account, to_email))
      return if response.status < 300

      Api.logger.error("SendGrid error #{response.status}: #{response.body}")
    end

    def mail_json(participant, account, to_email)
      owner     = @bill.creator&.username
      bill_link = @app_url.empty? ? '' : "\n\nView and respond here:\n#{@app_url}/bill-splits/#{@bill.id}"
      {
        personalizations: [{ to: [{ email: to_email }] }],
        from:    { email: from_email, name: from_name },
        subject: "#{owner} sent you a bill split: #{@bill.title}",
        content: [{
          type:  'text/plain',
          value: <<~TEXT
            Hi #{account.username},

            #{owner} has sent you a bill split on Fintrack.

            Bill:       #{@bill.title}
            Your share: $#{@bill.total_for(participant)}#{bill_link}

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
