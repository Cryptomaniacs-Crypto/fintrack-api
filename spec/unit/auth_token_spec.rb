# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthToken' do
  let(:payload) do
    { 'type' => 'account', 'attributes' => { 'id' => 'abc-123', 'username' => 'jane' } }
  end

  it 'HAPPY: round-trips its payload through encrypt/decrypt' do
    token = FinanceTracker::AuthToken.new(payload).to_s
    loaded = FinanceTracker::AuthToken.load(token)
    _(loaded.payload).must_equal payload
  end

  it 'HAPPY: persists and restores the scope' do
    token = FinanceTracker::AuthToken.new(
      payload, scope: FinanceTracker::AuthScope.new(FinanceTracker::AuthScope::READ_ONLY)
    ).to_s
    loaded = FinanceTracker::AuthToken.load(token)
    _(loaded.scope.to_s).must_equal FinanceTracker::AuthScope::READ_ONLY
    _(loaded.scope.can_write?('wallets')).must_equal false
  end

  it 'HAPPY: defaults to a FULL scope' do
    loaded = FinanceTracker::AuthToken.load(FinanceTracker::AuthToken.new(payload).to_s)
    _(loaded.scope.can_write?('wallets')).must_equal true
  end

  it 'SECURITY: raises InvalidTokenError on a garbage/tampered token' do
    _(proc { FinanceTracker::AuthToken.load('not-a-real-token') })
      .must_raise FinanceTracker::AuthToken::InvalidTokenError
  end

  it 'SECURITY: a token is opaque (does not leak the payload in plaintext)' do
    token = FinanceTracker::AuthToken.new(payload).to_s
    _(token).wont_include 'abc-123'
    _(token).wont_include 'jane'
  end

  it 'SAD: raises ExpiredTokenError once past expiry' do
    token = FinanceTracker::AuthToken.new(payload, -1).to_s
    loaded = FinanceTracker::AuthToken.load(token)
    _(proc { loaded.payload }).must_raise FinanceTracker::AuthToken::ExpiredTokenError
  end
end
