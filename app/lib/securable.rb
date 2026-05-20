# frozen_string_literal: true

require 'base64'
require 'rbnacl'

module FinanceTracker
  # Shared cryptographic helpers used by SecureDB and other components.
  module Securable
    class NoKeyError < StandardError; end
    class NoHashKeyError < StandardError; end

    def generate_key
      key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
      Base64.strict_encode64 key
    end

    def setup(base_key)
      raise NoKeyError unless base_key
      @key = Base64.strict_decode64(base_key)
    end

    def key
      @key
    end

    def base_encrypt(plaintext)
      simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
      Base64.strict_encode64(simple_box.encrypt(plaintext))
    end

    def base_decrypt(ciphertext64)
      simple_box = RbNaCl::SimpleBox.from_secret_key(@key)
      simple_box.decrypt(Base64.strict_decode64(ciphertext64)).force_encoding(Encoding::UTF_8)
    end

    def setup_hash_key(hash_key)
      raise NoHashKeyError unless hash_key
      @hash_key = Base64.strict_decode64(hash_key)
    end

    def base_hash(plaintext)
      return nil unless plaintext
      digest = RbNaCl::HMAC::SHA256.auth(@hash_key, plaintext.to_s)
      Base64.strict_encode64(digest)
    end

    module_function :generate_key, :setup, :key, :base_encrypt, :base_decrypt, :setup_hash_key, :base_hash
  end
end
