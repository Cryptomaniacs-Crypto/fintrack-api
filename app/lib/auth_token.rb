# frozen_string_literal: true

require 'json'

require_relative 'securable'

module FinanceTracker
  # Time-limited encrypted token carrying an opaque account payload.
  class AuthToken
    extend Securable

    class ExpiredTokenError < StandardError; end
    class InvalidTokenError < StandardError; end

    ONE_HOUR  = 60 * 60
    ONE_DAY   = ONE_HOUR * 24
    ONE_WEEK  = ONE_DAY * 7
    ONE_MONTH = ONE_DAY * 30
    ONE_YEAR  = ONE_DAY * 365

    def self.setup(base_key)
      Securable.setup(base_key)
    end

    def self.setup_secret_key(base_key)
      Securable.setup(base_key)
    end

    def self.create(account)
      new(
        {
          account_id: account.id,
          username: account.username
        }
      ).to_s
    end

    def self.tokenize(message)
      base_encrypt(JSON.generate(message))
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
end# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module FinanceTracker
  # Encodes and validates bearer tokens for authenticated requests.
  class AuthToken
    class ExpiredTokenError < StandardError; end
    class InvalidTokenError < StandardError; end

    EXPIRATION = 24 * 60 * 60
    TOKEN_TTL = EXPIRATION

    class << self
      def setup(secret_key)
        raise InvalidTokenError unless secret_key

        @secret_key = Base64.strict_decode64(secret_key)
      end

      def create(account)
        payload = {
          account_id: account.id,
          username: account.username,
          expires_at: Time.now.to_i + EXPIRATION
        }

        Base64.strict_encode64(box.encrypt(JSON.generate(payload)))
      end

      def load(token)
        payload = JSON.parse(box.decrypt(Base64.strict_decode64(token)), symbolize_names: true)
        raise ExpiredTokenError if payload[:expires_at].to_i <= Time.now.to_i

        payload
      rescue JSON::ParserError, ArgumentError, RbNaCl::CryptoError, EncodingError
        raise InvalidTokenError
      end

      private

      def box
        RbNaCl::SimpleBox.from_secret_key(@secret_key)
      end
    end
  end
end