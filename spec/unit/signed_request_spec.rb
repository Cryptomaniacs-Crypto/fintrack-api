# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SignedRequest' do
  # Preserve the boot-configured keypair: integration specs sign with it.
  before do
    @saved_verify = FinanceTracker::SignedRequest.instance_variable_get(:@verify_key)
    @saved_signing = FinanceTracker::SignedRequest.instance_variable_get(:@signing_key)
  end

  after do
    FinanceTracker::SignedRequest.instance_variable_set(:@verify_key, @saved_verify)
    FinanceTracker::SignedRequest.instance_variable_set(:@signing_key, @saved_signing)
  end

  it 'BAD: setup with an invalid key raises KeypairError' do
    _(proc { FinanceTracker::SignedRequest.setup('not-a-base64-key!') })
      .must_raise FinanceTracker::SignedRequest::KeypairError
  end

  it 'HAPPY: generate_keypair returns 32-byte base64 signing/verify halves' do
    kp = FinanceTracker::SignedRequest.generate_keypair

    _(Base64.strict_decode64(kp[:signing_key]).bytesize).must_equal 32
    _(Base64.strict_decode64(kp[:verify_key]).bytesize).must_equal 32
  end

  it 'HAPPY: parse returns the data when the signature verifies' do
    kp = FinanceTracker::SignedRequest.generate_keypair
    FinanceTracker::SignedRequest.setup(kp[:verify_key], kp[:signing_key])

    signed = FinanceTracker::SignedRequest.sign({ username: 'u', password: 'p' })
    # The controller parses the incoming JSON body with symbolized names.
    parsed = JSON.parse(signed.to_json, symbolize_names: true)

    _(FinanceTracker::SignedRequest.parse(parsed)).must_equal({ username: 'u', password: 'p' })
  end

  it 'SECURITY: a tampered body fails verification' do
    kp = FinanceTracker::SignedRequest.generate_keypair
    FinanceTracker::SignedRequest.setup(kp[:verify_key], kp[:signing_key])

    signed = FinanceTracker::SignedRequest.sign({ amount: 1 })
    tampered = { data: { amount: 9999 }, signature: signed[:signature] }

    _(proc { FinanceTracker::SignedRequest.parse(tampered) })
      .must_raise FinanceTracker::SignedRequest::VerificationError
  end

  it 'SECURITY: a missing signature fails verification' do
    _(proc { FinanceTracker::SignedRequest.parse({ data: { a: 1 }, signature: nil }) })
      .must_raise FinanceTracker::SignedRequest::VerificationError
  end

  it 'BAD: signing without a signing key raises KeypairError' do
    # Verify-only setup (production posture): no signing half.
    FinanceTracker::SignedRequest.setup(FinanceTracker::SignedRequest.generate_keypair[:verify_key])

    _(proc { FinanceTracker::SignedRequest.sign({ a: 1 }) })
      .must_raise FinanceTracker::SignedRequest::KeypairError
  end
end
