# frozen_string_literal: true

require 'json'
require 'sequel'
require_relative '../lib/secure_db'
require_relative 'password'

module FinanceTracker
  # Models a registered user account.
  class Account < Sequel::Model
    many_to_many :system_roles,
                 class: :'FinanceTracker::Role',
                 join_table: :accounts_roles,
                 left_key: :account_id,
                 right_key: :role_id

    plugin :uuid, field: :id
    plugin :timestamps, update_on_create: true
    plugin :whitelist_security
    set_allowed_columns :username, :email, :password, :avatar

    # Email is PII: store encrypted ciphertext + HMAC lookup hash.
    def email
      SecureDB.decrypt(email_secure)
    end

    def email=(plaintext)
      self.email_secure = SecureDB.encrypt(plaintext)
      self.email_hash   = SecureDB.hash(plaintext)
    end

    def password=(new_password)
      self.password_digest = Password.digest(new_password).to_s
    end

    def password?(try_password)
      digest = Password.from_digest(password_digest)
      digest.correct?(try_password)
    end

    def to_json(options = {})
      JSON(
        {
          data: {
            type: 'account',
            attributes: {
              id:,
              username:,
              email:,
              avatar:
            }
          }
        }, options
      )
    end
  end
end
