# frozen_string_literal: true

require 'base64'
require 'rbnacl'

module FinanceTracker
  # Encrypt and decrypt values stored in database fields.
  class SecureDB
    class NoDbKeyError < StandardError; end

    class << self
      # Generate a Base64 key to use as SECURE_DB_KEY.
      def generate_key
        key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
        Base64.strict_encode64(key)
      end

      def setup(base_key)
        raise NoDbKeyError unless base_key

        @key = Base64.strict_decode64(base_key)
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
    end
  end
end
