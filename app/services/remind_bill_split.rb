# frozen_string_literal: true

require 'http'

module FinanceTracker
  # Sends a payment reminder email to each non-owner participant who has not yet
  # paid their share of a sent bill split, provided at least 3 days have passed
  # since the bill was sent (or since the last reminder). Safe to call daily —
  # the 3-day gate is enforced here, not in the scheduler.
  class RemindBillSplit
    THREE_DAYS_SECS = 60 * 60 # 1 hour for testing (change back to 3 * 24 * 60 * 60)

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

      bill          = participant.bill_split
      row           = bill.breakdown.find { |r| r[:account_id] == participant.account_id }
      amount        = row ? row[:total] : '?'
      owner_wallets = Wallet.where(account_id: bill.creator_id).all
      bill_link     = ENV.fetch('APP_URL', '').chomp('/').then { |u| u.empty? ? nil : "#{u}/bill-splits/#{bill.id}" }

      response = HTTP
                   .auth("Bearer #{api_key}")
                   .post(mail_url, json: mail_json(account, bill, amount, owner_wallets, bill_link))
      return if response.status < 300

      Api.logger.error("SendGrid reminder error #{response.status}: #{response.body}")
    end

    def mail_json(account, bill, amount, owner_wallets, bill_link)
      {
        personalizations: [{ to: [{ email: account.email }] }],
        from:    { email: from_email, name: from_name },
        subject: "Reminder: pay your share for '#{bill.title}'",
        content: [
          { type: 'text/plain', value: text_body(account, bill, amount, owner_wallets, bill_link) },
          { type: 'text/html',  value: html_body(account, bill, amount, owner_wallets, bill_link) }
        ]
      }
    end

    def text_body(account, bill, amount, owner_wallets, bill_link)
      payment_lines = owner_wallets.map { |w| "  • #{w.name} (#{w.method_type.to_s.tr('_', ' ')})" }
      payment_info  = payment_lines.empty? ? '  Contact the bill owner directly.' : payment_lines.join("\n")
      link_line     = bill_link ? "\nView and respond here:\n#{bill_link}\n" : ''

      <<~TEXT
        Hi #{account.username},

        This is a friendly reminder that you have an unpaid share in a bill split from #{bill.creator&.username}.

        Bill:       #{bill.title}
        Your share: $#{amount}

        Please review and respond at your earliest convenience.

        Payment options:
        #{payment_info}

        Or arrange another payment method with #{bill.creator&.username} directly.
        #{link_line}
        — Fintrack
      TEXT
    end

    def html_body(account, bill, amount, owner_wallets, bill_link)
      payment_rows = if owner_wallets.empty?
        '<p style="margin:0;font-size:14px;color:#888;">Contact the bill owner directly for payment details.</p>'
      else
        items = owner_wallets.map do |w|
          type_label = w.method_type.to_s.tr('_', ' ').split.map(&:capitalize).join(' ')
          "<li style='padding:5px 0;font-size:14px;color:#555;'>"\
          "<strong>#{w.name}</strong> "\
          "<span style='color:#999;font-size:13px;'>(#{type_label})</span></li>"
        end.join
        "<ul style='margin:8px 0 0;padding-left:20px;list-style:disc;'>#{items}</ul>"
      end

      button = if bill_link
        <<~BTN
          <div style="text-align:center;margin:28px 0;">
            <a href="#{bill_link}" style="display:inline-block;background-color:#1a1a1a;color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:6px;font-weight:bold;font-size:15px;">View Bill Split</a>
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

                <tr><td style="background-color:#1a1a1a;padding:20px 32px;">
                  <span style="color:#ffffff;font-size:22px;font-weight:bold;letter-spacing:-0.5px;">Fintrack</span>
                </td></tr>

                <tr><td style="padding:36px 32px 28px;">
                  <p style="margin:0 0 16px;font-size:16px;color:#333;">Hi <strong>#{account.username}</strong>,</p>
                  <p style="margin:0 0 24px;font-size:15px;color:#555;line-height:1.6;">
                    This is a friendly reminder that you have an unpaid bill split request from <strong>#{bill.creator&.username}</strong>.
                  </p>

                  <table cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f8f9fa;border-radius:6px;margin-bottom:24px;">
                    <tr><td style="padding:20px 24px;">
                      <p style="margin:0 0 4px;font-size:12px;color:#999;text-transform:uppercase;letter-spacing:0.5px;">Bill</p>
                      <p style="margin:0 0 16px;font-size:18px;font-weight:bold;color:#333;">#{bill.title}</p>
                      <p style="margin:0 0 4px;font-size:12px;color:#999;text-transform:uppercase;letter-spacing:0.5px;">Your Share</p>
                      <p style="margin:0;font-size:26px;font-weight:bold;color:#1a1a1a;">$#{amount}</p>
                    </td></tr>
                  </table>

                  <p style="margin:0 0 8px;font-size:14px;font-weight:bold;color:#333;">
                    Pay to #{bill.creator&.username}'s payment method:
                  </p>
                  #{payment_rows}
                  <p style="margin:12px 0 0;font-size:13px;color:#999;">
                    Or other ways — arrange directly with <strong>#{bill.creator&.username}</strong>.
                  </p>

                  #{button}
                </td></tr>

                <tr><td style="background:#f8f9fa;padding:16px 32px;text-align:center;border-top:1px solid #eee;">
                  <p style="margin:0;font-size:12px;color:#bbb;">© Fintrack · You received this because you have an unpaid bill split.</p>
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
