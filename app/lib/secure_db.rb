# frozen_string_literal: true

require 'base64'
require 'rbnacl'

module FinanceTracker
  # Encrypt and decrypt values stored in database fields, plus
  # keyed HMAC for deterministic lookup on encrypted columns.
  class SecureDB
    class NoDbKeyError < StandardError; end
    class NoHashKeyError < StandardError; end

    class << self
      # Generate a Base64 key for SECURE_DB_KEY or SECURE_HASH_KEY.
      def generate_key
        key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
        Base64.strict_encode64(key)
      end

      def setup(db_key, hash_key)
        raise NoDbKeyError unless db_key
        raise NoHashKeyError unless hash_key

        @key = Base64.strict_decode64(db_key)
        @hash_key = Base64.strict_decode64(hash_key)
      end

      # Encrypt or return nil when value is nil.
      def encrypt(plaintext)
        return nil unless plaintext

        simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
        ciphertext = simple_box.encrypt(plaintext.to_s)
        Base64.strict_encode64(ciphertext)
      end

      # Decrypt or return nil when value is nil.
      def decrypt(ciphertext64)
        return nil unless ciphertext64

        ciphertext = Base64.strict_decode64(ciphertext64)
        simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
        simple_box.decrypt(ciphertext).force_encoding(Encoding::UTF_8)
      end

      # Keyed HMAC for deterministic lookup on encrypted columns.
      def hash(plaintext)
        return nil unless plaintext

        digest = RbNaCl::HMAC::SHA256.auth(@hash_key, plaintext.to_s)
        Base64.strict_encode64(digest)
      end
    end
  end
end
