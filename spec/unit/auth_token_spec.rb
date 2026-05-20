# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test FinanceTracker::AuthToken' do
  let(:payload) { { 'account_id' => 7, 'username' => 'chen.hsinyi' } }

  it 'SECURITY: should produce a string token from a payload' do
    token = FinanceTracker::AuthToken.new(payload).to_s
    _(token).must_be_kind_of String
    _(token).wont_be_empty
    _(token).wont_include 'chen.hsinyi'
  end

  it 'SECURITY: should round-trip a payload via new then load' do
    token = FinanceTracker::AuthToken.new(payload).to_s
    loaded = FinanceTracker::AuthToken.load(token)
    _(loaded.payload).must_equal payload
  end

  it 'SECURITY: should expose a freshness predicate on a new token' do
    auth_token = FinanceTracker::AuthToken.new(payload)
    _(auth_token.fresh?).must_equal true
    _(auth_token.expired?).must_equal false
  end

  it 'SECURITY: should report expired when expiration has passed' do
    auth_token = FinanceTracker::AuthToken.new(payload, -1)
    _(auth_token.expired?).must_equal true
    _(auth_token.fresh?).must_equal false
  end

  it 'SECURITY: should raise ExpiredTokenError when reading payload of expired token' do
    token = FinanceTracker::AuthToken.new(payload, -1).to_s
    loaded = FinanceTracker::AuthToken.load(token)
    _ { loaded.payload }.must_raise FinanceTracker::AuthToken::ExpiredTokenError
  end

  it 'SECURITY: should raise InvalidTokenError on garbage input' do
    _ { FinanceTracker::AuthToken.load('not-a-real-token') }
      .must_raise FinanceTracker::AuthToken::InvalidTokenError
  end

  it 'SECURITY: should raise InvalidTokenError on tampered token' do
    token = FinanceTracker::AuthToken.new(payload).to_s
    tampered = "#{token[0..-3]}XX"
    _ { FinanceTracker::AuthToken.load(tampered) }
      .must_raise FinanceTracker::AuthToken::InvalidTokenError
  end

  it 'SECURITY: should produce a generate_key string usable by setup' do
    key = FinanceTracker::AuthToken.generate_key
    _(key).must_be_kind_of String
    _(key).wont_be_empty
  end
end
