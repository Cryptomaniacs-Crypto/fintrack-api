# frozen_string_literal: true

require 'http'

module FinanceTracker
  # Sends a verification email to a prospective account-holder so that
  # only someone who can read the inbox can finish account creation.
  class VerifyRegistration
    class InvalidRegistration < StandardError; end
    class EmailProviderError < StandardError; end

    def initialize(registration)
      @registration = registration
    end

    def call
      validate_registration!
      raise InvalidRegistration, 'Email already registered' unless email_available?
      raise InvalidRegistration, 'Username already taken' unless username_available?

      send_email
      @registration
    end

    private

    def email
      @registration[:email] || @registration['email']
    end

    def username
      @registration[:username] || @registration['username']
    end

    def verification_url
      @registration[:verification_url] || @registration['verification_url']
    end

    def validate_registration!
      raise InvalidRegistration, 'Email is required' if email.to_s.strip.empty?
      raise InvalidRegistration, 'Username is required' if username.to_s.strip.empty?
      raise InvalidRegistration, 'Verification URL is required' if verification_url.to_s.strip.empty?
    end

    def email_available?
      Account.first(email_hash: SecureDB.hash(email)).nil?
    end

    def username_available?
      Account.first(username: username).nil?
    end

    def send_email
      response = HTTP
                 .basic_auth(user: 'api', pass: api_key)
                 .post(mail_url, form: mail_params)
      return if response.status < 300

      Api.logger.error("Mailgun error #{response.status}: #{response.body}")
      raise EmailProviderError, 'Email provider rejected the request'
    end

    def api_key    = ENV.fetch('MAILGUN_API_KEY')
    def domain     = ENV.fetch('MAILGUN_DOMAIN')
    def mail_url   = "https://api.mailgun.net/v3/#{domain}/messages"
    def from_email = ENV.fetch('MAILGUN_FROM_EMAIL')
    def from_name  = ENV.fetch('MAILGUN_FROM_NAME', 'Fintrack')

    def mail_params
      {
        from:    "#{from_name} <#{from_email}>",
        to:      email,
        subject: 'Fintrack Registration Verification',
        html:    html_body
      }
    end

    def html_body
      <<~HTML
        <h2>Welcome to Fintrack, #{username}!</h2>
        <p>Click the link below to finish creating your account:</p>
        <p><a href="#{verification_url}">Verify your registration</a></p>
        <p>If you didn't request this, you can safely ignore this email.</p>
      HTML
    end
  end
end
