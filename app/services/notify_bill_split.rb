# frozen_string_literal: true

require 'http'

module FinanceTracker
  # Emails each non-owner participant when a bill split is sent to them.
  # Credentials are read from MAILGUN_* ENV vars (set as Heroku config vars).
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
      return if api_key.to_s.strip.empty? || domain.to_s.strip.empty?

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

      email = account.email
      return if email.to_s.strip.empty?

      response = HTTP
                 .basic_auth(user: 'api', pass: api_key)
                 .post(mail_url, form: mail_params(participant, account, email))
      return if response.status < 300

      Api.logger.error("Mailgun error #{response.status}: #{response.body}")
    end

    def mail_params(participant, account, email)
      owner     = @bill.creator&.username
      bill_link = @app_url.empty? ? '' : "\n\nView and respond here:\n#{@app_url}/bill-splits/#{@bill.id}"
      {
        from:    "#{from_name} <#{from_email}>",
        to:      email,
        subject: "#{owner} sent you a bill split: #{@bill.title}",
        text:    <<~TEXT
          Hi #{account.username},

          #{owner} has sent you a bill split on Fintrack.

          Bill:       #{@bill.title}
          Your share: $#{@bill.total_for(participant)}#{bill_link}

          — Fintrack
        TEXT
      }
    end

    def api_key    = ENV.fetch('MAILGUN_API_KEY', nil)
    def domain     = ENV.fetch('MAILGUN_DOMAIN', nil)
    def mail_url   = "https://api.mailgun.net/v3/#{domain}/messages"
    def from_email = ENV.fetch('MAILGUN_FROM_EMAIL', "noreply@#{domain}")
    def from_name  = ENV.fetch('MAILGUN_FROM_NAME', 'Fintrack')
  end
end
