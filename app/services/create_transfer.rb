# frozen_string_literal: true

require 'date'

module FinanceTracker
  # Moves money between two wallets owned by the same account as a single,
  # atomic operation. The transfer is stored as two legs (an expense on the
  # source wallet + an income on the destination wallet), mirroring how the
  # rest of the app represents transfers; both legs are created inside one
  # DB transaction so they commit together or not at all. A partial transfer
  # (money leaving the source but never reaching the destination) can never
  # be observed.
  class CreateTransfer
    class InvalidInput < StandardError; end

    # rubocop:disable Metrics/ParameterLists
    def self.call(account:, from_wallet_id:, to_wallet_id:, amount:, title:, transaction_date:, note: nil)
      raise InvalidInput, 'Source and destination wallets must be different' if from_wallet_id.to_s == to_wallet_id.to_s

      magnitude = positive_amount!(amount)

      details = { title:, transaction_date:, note: }

      FinanceTracker::Api.DB.transaction do
        from_wallet = WalletOwnership.owned!(account, from_wallet_id, InvalidInput)
        to_wallet   = WalletOwnership.owned!(account, to_wallet_id, InvalidInput)
        record_legs(from_wallet, to_wallet, magnitude, details)
      end
    end
    # rubocop:enable Metrics/ParameterLists

    # Creates the paired expense/income legs. Returns both records.
    def self.record_legs(from_wallet, to_wallet, magnitude, details)
      expense = FinanceTracker::Transaction.create(
        title: "Transfer → #{details[:title]}", amount: "-#{magnitude}",
        transaction_date: details[:transaction_date], wallet_id: from_wallet.id, note: details[:note]
      )
      income = FinanceTracker::Transaction.create(
        title: "Transfer ← #{details[:title]}", amount: magnitude.to_s,
        transaction_date: details[:transaction_date], wallet_id: to_wallet.id, note: details[:note]
      )
      { from: expense, to: income }
    end

    def self.positive_amount!(raw_amount)
      parsed = Float(raw_amount.to_s.strip, exception: false)
      raise InvalidInput, 'Amount must be a valid number' unless parsed
      raise InvalidInput, 'Amount must be greater than zero' unless parsed.positive?

      # Drop any leading sign the caller may have sent; legs apply their own.
      raw_amount.to_s.strip.delete_prefix('-').delete_prefix('+')
    end
  end
end
