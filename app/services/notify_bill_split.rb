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
      amount    = @bill.total_for(participant)
      bill_link = @app_url.empty? ? nil : "#{@app_url}/bill-splits/#{@bill.id}"

      {
        personalizations: [{ to: [{ email: to_email }] }],
        from:    { email: from_email, name: from_name },
        subject: "#{owner} sent you a bill split: #{@bill.title}",
        content: [
          { type: 'text/plain', value: text_body(account, owner, amount, bill_link) },
          { type: 'text/html',  value: html_body(account, owner, amount, bill_link) }
        ]
      }
    end

    def text_body(account, owner, amount, bill_link)
      link_line = bill_link ? "\nView and respond here:\n#{bill_link}\n" : ''
      <<~TEXT
        Hi #{account.username},

        A new bill split has been shared with you by #{owner}.

        Bill:       #{@bill.title}
        Amount due: $#{amount}

        Tap the link below to view the details and take action.
        #{link_line}
        — Fintrack
      TEXT
    end

    def html_body(account, owner, amount, bill_link)
      button = if bill_link
        <<~BTN
          <div style="text-align:center;margin:28px 0;">
            <a href="#{bill_link}" style="display:inline-block;background-color:#2FA4E7;color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:6px;font-weight:bold;font-size:15px;">Open Bill Split</a>
          </div>
        BTN
      else
        ''
      end

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
                  <p style="margin:0 0 16px;font-size:16px;color:#333;">Hi <strong>#{account.username}</strong>,</p>
                  <p style="margin:0 0 24px;font-size:15px;color:#555;line-height:1.6;">
                    A new bill split has been shared with you by <strong>#{owner}</strong>.
                  </p>

                  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f8f9fa;border-radius:6px;margin-bottom:8px;">
                    <tr><td style="padding:20px 24px;">
                      <p style="margin:0 0 4px;font-size:12px;color:#999;text-transform:uppercase;letter-spacing:0.5px;">Bill</p>
                      <p style="margin:0 0 16px;font-size:18px;font-weight:bold;color:#333;">#{@bill.title}</p>
                      <p style="margin:0 0 4px;font-size:12px;color:#999;text-transform:uppercase;letter-spacing:0.5px;">Amount Due</p>
                      <p style="margin:0;font-size:26px;font-weight:bold;color:#2FA4E7;">$#{amount}</p>
                    </td></tr>
                  </table>

                  #{button}

                  <p style="margin:0;font-size:13px;color:#aaa;line-height:1.6;text-align:center;">
                    Tap the button above to view the details and take action.
                  </p>
                </td></tr>

                <tr><td style="background:#f8f9fa;padding:16px 32px;text-align:center;border-top:1px solid #eee;">
                  <p style="margin:0;font-size:12px;color:#bbb;">© Fintrack · You received this because you were added to a bill split.</p>
                </td></tr>

              </table>
            </td></tr>
          </table>
        </body>
        </html>
      HTML
    end

    def api_key    = ENV.fetch('SENDGRID_API_KEY', nil)
    def mail_url   = 'https://api.sendgrid.com/v3/mail/send'
    def from_email = ENV.fetch('SENDGRID_FROM_EMAIL', nil)
    def from_name  = ENV.fetch('SENDGRID_FROM_NAME', 'Fintrack')
  end
end
