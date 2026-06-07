# frozen_string_literal: true

require 'rbnacl'
require 'base64'
require 'json'

module FinanceTracker
  # Verifies digitally signed requests from the Web App.
  #
  # Production holds only the public VERIFY_KEY, so it can verify but never
  # sign (non-repudiation). The signing half is loaded ONLY in the test
  # environment, where specs must forge client signatures.
  #
  # Signed body shape: { data: <message>, signature: <base64> }. The signature
  # is checked against `data.to_json` -- the exact bytes the app signed.
  class SignedRequest
    class VerificationError < StandardError; end
    class KeypairError < StandardError; end

    class << self
      def setup(verify_key64, signing_key64 = nil)
        @verify_key = Base64.strict_decode64(verify_key64)
        @signing_key = signing_key64 ? Base64.strict_decode64(signing_key64) : nil
      rescue StandardError
        raise KeypairError, 'Invalid verification/signing keypair'
      end

      def generate_keypair
        signing_key = RbNaCl::SigningKey.generate
        {
          signing_key: Base64.strict_encode64(signing_key.to_bytes),
          verify_key: Base64.strict_encode64(signing_key.verify_key.to_bytes)
        }
      end

      # Returns the inner data hash iff the signature verifies; else raises.
      def parse(signed)
        signed[:data] if verify(signed[:data], signed[:signature])
      end

      def verify(message, signature64)
        raise VerificationError if message.nil? || signature64.nil?

        signature = Base64.strict_decode64(signature64)
        RbNaCl::VerifyKey.new(verify_key!).verify(signature, message.to_json)
      rescue StandardError
        raise VerificationError
      end

      # Test-only: forge a client signature (test env loads the signing half).
      def sign(message)
        raise KeypairError, 'No signing key configured' unless @signing_key

        signature = RbNaCl::SigningKey.new(@signing_key)
                                      .sign(message.to_json)
                                      .then { |sig| Base64.strict_encode64(sig) }
        { data: message, signature: signature }
      end

      private

      def verify_key!
        raise KeypairError, 'SignedRequest.setup must be called first' unless @verify_key

        @verify_key
      end
    end
  end
end
