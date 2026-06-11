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
    one_to_many :sso_identities
    # One-way contact list: the accounts this account has saved as friends.
    # Directional and not auto-reciprocal (see migration 014).
    many_to_many :friends,
                 class: :'FinanceTracker::Account',
                 join_table: :friendships,
                 left_key: :account_id,
                 right_key: :friend_id
    plugin :association_dependencies, system_roles: :nullify, sso_identities: :destroy, friends: :nullify

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

    # Home-banner cover photo (base64), stored encrypted like payment proofs.
    def banner_image
      banner_image_secure.nil? ? nil : SecureDB.decrypt(banner_image_secure)
    end

    def banner_image=(base64)
      self.banner_image_secure = base64.to_s.empty? ? nil : SecureDB.encrypt(base64)
    end

    def banner? = !banner_image_secure.nil?

    def password=(new_password)
      self.password_digest = Password.digest(new_password).to_s
    end

    def password?(try_password)
      digest = Password.from_digest(password_digest)
      digest.correct?(try_password)
    end

    # Role-predicate shortcuts for controllers and policies.
    def admin?  = system_roles.any?(&:admin?)
    def member? = system_roles.any?(&:member?)

    # System-level capabilities for this account.
    # Delegates to AccountPolicy so the rules stay in one place.
    def capability
      AccountPolicy.new(self).capabilities
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
