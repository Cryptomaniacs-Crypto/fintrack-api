# frozen_string_literal: true

module FinanceTracker
  # Renames an account's username after validating format + uniqueness.
  # Relationships (bill splits, transactions, settlements) reference the
  # immutable account UUID, so a rename never breaks history -- only the
  # human-facing handle changes.
  class UpdateAccountUsername
    class InvalidUsernameError < StandardError; end
    class UsernameTakenError < StandardError; end

    MIN_LENGTH = 4
    MAX_LENGTH = 50
    # ASCII letters, digits, dots, underscores -- mirrors the app's USERNAME_REGEX.
    FORMAT = /\A[A-Za-z0-9._]+\z/

    def self.call(account:, new_username:)
      name = new_username.to_s.strip
      validate!(name)
      return account if name == account.username # no-op rename

      account.username = name
      account.save_changes
      account
    rescue Sequel::UniqueConstraintViolation
      raise UsernameTakenError, 'Username already taken'
    end

    def self.validate!(name)
      unless name.length.between?(MIN_LENGTH, MAX_LENGTH)
        raise InvalidUsernameError, "Username must be #{MIN_LENGTH}-#{MAX_LENGTH} characters"
      end
      return if FORMAT.match?(name)

      raise InvalidUsernameError, 'Username may contain only letters, digits, dots, or underscores'
    end
  end
end
