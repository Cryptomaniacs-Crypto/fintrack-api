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
                 .auth("Bearer #{api_key}")
                 .post(mail_url, json: mail_json)
      return if response.status < 300

      Api.logger.error("SendGrid error #{response.status}: #{response.body}")
      raise EmailProviderError, 'Email provider rejected the request'
    end

    def api_key    = ENV.fetch('SENDGRID_API_KEY')
    def mail_url   = 'https://api.sendgrid.com/v3/mail/send'
    def from_email = ENV.fetch('SENDGRID_FROM_EMAIL')
    def from_name  = ENV.fetch('SENDGRID_FROM_NAME', 'Fintrack')

    def mail_json
      {
        personalizations: [{ to: [{ email: email }] }],
        from:    { email: from_email, name: from_name },
        subject: 'Verify your Fintrack account',
        content: [
          { type: 'text/plain', value: text_body },
          { type: 'text/html',  value: html_body }
        ]
      }
    end

    def text_body
      <<~TEXT
        Hi #{username},

        Thanks for signing up for Fintrack!

        Click the link below to verify your email address and activate your account:

        #{verification_url}

        If you didn't sign up for Fintrack, you can safely ignore this email.

        — Fintrack
      TEXT
    end

    def html_body
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body style="margin:0;padding:0;background-color:#f4f6f8;font-family:Arial,Helvetica,sans-serif;">
          <table width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f4f6f8" style="padding:40px 16px;">
            <tr><td align="center">
              <table width="560" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);max-width:560px;">

                <tr><td style="background-color:#2FA4E7;padding:20px 32px;">
                  <span style="color:#ffffff;font-size:22px;font-weight:bold;letter-spacing:-0.5px;">Fintrack</span>
                </td></tr>

                <tr><td style="padding:36px 32px 28px;">
                  <p style="margin:0 0 16px;font-size:16px;color:#333;">Hi <strong>#{username}</strong>,</p>
                  <p style="margin:0 0 12px;font-size:15px;color:#555;line-height:1.6;">
                    Thanks for signing up for Fintrack.
                  </p>
                  <p style="margin:0 0 28px;font-size:15px;color:#555;line-height:1.6;">
                    Click the button below to verify your email address and activate your account. Once verified, you can start tracking your spending, organising shared expenses, and managing your finances.
                  </p>

                  <div style="text-align:center;margin-bottom:28px;">
                    <a href="#{verification_url}" style="display:inline-block;background-color:#2FA4E7;color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:6px;font-weight:bold;font-size:15px;">Verify Account</a>
                  </div>

                  <p style="margin:0;font-size:13px;color:#aaa;line-height:1.6;">
                    If you didn't sign up for Fintrack, you can safely ignore this email.
                  </p>
                </td></tr>

                <tr><td style="background:#f8f9fa;padding:16px 32px;text-align:center;border-top:1px solid #eee;">
                  <p style="margin:0;font-size:12px;color:#bbb;">© Fintrack · Happy tracking!</p>
                </td></tr>

              </table>
            </td></tr>
          </table>
        </body>
        </html>
      HTML
    end
  end
end
