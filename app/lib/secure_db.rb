# frozen_string_literal: true

require_relative 'securable'

module FinanceTracker
  # Encrypt and decrypt values stored in database fields, plus keyed HMAC.
  class SecureDB
    extend Securable

    # Public helper to produce a Base64 key for use in secrets.
    def self.generate_key
      Securable.generate_key
    end

    def self.setup(db_key, hash_key)
      raise Securable::NoKeyError unless db_key
      raise Securable::NoHashKeyError unless hash_key

      @key      = Base64.strict_decode64(db_key)
      @hash_key = Base64.strict_decode64(hash_key)
    end

    def self.encrypt(plaintext)
      return nil unless plaintext

      base_encrypt(plaintext.to_s)
    end

    def self.decrypt(ciphertext64)
      return nil unless ciphertext64

      base_decrypt(ciphertext64)
    end

    # Keyed HMAC for deterministic lookup on encrypted columns.
    def self.hash(plaintext)
      return nil unless plaintext

      base_hash(plaintext.to_s)
    end
  end
end
