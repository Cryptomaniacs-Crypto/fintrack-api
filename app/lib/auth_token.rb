# frozen_string_literal: true

require 'base64'
require 'json'

require_relative 'securable'

module FinanceTracker
  # Time-limited encrypted token carrying an opaque account payload.
  # Used as the Bearer token for authenticated API requests.
  class AuthToken
    extend Securable

    class ExpiredTokenError < StandardError; end
    class InvalidTokenError < StandardError; end

    ONE_HOUR  = 60 * 60
    ONE_DAY   = ONE_HOUR * 24
    ONE_WEEK  = ONE_DAY * 7

    def self.setup(base_key)
      raise Securable::NoKeyError unless base_key

      @key = Base64.strict_decode64(base_key)
    end

    def self.tokenize(message)
      base_encrypt(JSON.generate(message))
    rescue StandardError
      raise InvalidTokenError
    end

    def self.detokenize(ciphertext64)
      JSON.parse(base_decrypt(ciphertext64))
    rescue StandardError
      raise InvalidTokenError
    end

    def self.load(token)
      contents = detokenize(token)
      instance = allocate
      instance.instance_variable_set(:@token, token)
      instance.instance_variable_set(:@payload, contents['payload'])
      instance.instance_variable_set(:@expiration, contents['exp'])
      instance
    end

    def initialize(payload, expiration = ONE_WEEK)
      @payload = payload
      @expiration = (Time.now + expiration).to_i
      @token = self.class.tokenize('payload' => @payload, 'exp' => @expiration)
    end

    def payload
      raise ExpiredTokenError if expired?

      @payload
    end

    def expired?
      raise InvalidTokenError unless @expiration.is_a?(Integer)

      Time.now.to_i > @expiration
    end

    def fresh?
      !expired?
    end

    def to_s
      @token
    end
  end
end
