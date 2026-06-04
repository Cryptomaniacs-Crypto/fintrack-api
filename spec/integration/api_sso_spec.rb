# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test SSO Authentication API' do
  include Rack::Test::Methods

  before do
    wipe_database
    FinanceTracker::Role.find_or_create(name: 'member')
    # Stub Google's JWKS endpoint so no real network call is made
    require 'webmock/minitest'
    stub_request(:get, FinanceTracker::GoogleIdToken::JWKS_URI).to_return(
      body: SsoTestKeys.jwks.to_json,
      status: 200,
      headers: { 'content-type' => 'application/json' }
    )
  end

  after { WebMock.reset! }

  let(:json_header) { { 'CONTENT_TYPE' => 'application/json' } }

  describe 'POST /api/v1/auth/sso' do
    it 'HAPPY: a valid id_token creates an account and returns auth_token' do
      post '/api/v1/auth/sso',
           { id_token: SsoTestKeys.mint_id_token }.to_json,
           json_header

      _(last_response.status).must_equal 200

      body = JSON.parse(last_response.body)
      _(body['data']['attributes']['username']).must_equal 'sso-user'
      _(body['data']['attributes']['email']).must_equal 'sso-user@example.com'
      _(body['data']['attributes']['avatar']).must_equal SsoTestKeys.default_claims['picture']

      token = body['auth_token']
      _(token).must_be_kind_of String
      _(token).wont_be_empty
      _(FinanceTracker::AuthToken.load(token).scope.can_write?('wallets')).must_equal true
    end

    it 'HAPPY: a repeat login with the same identity reuses the same account' do
      2.times do
        post '/api/v1/auth/sso',
             { id_token: SsoTestKeys.mint_id_token }.to_json,
             json_header
      end

      _(last_response.status).must_equal 200
      _(FinanceTracker::SsoIdentity.where(provider: 'google').count).must_equal 1
      _(FinanceTracker::Account.count).must_equal 1
    end

    it 'HAPPY: returned auth_token carries FULL scope (SSO session = full access)' do
      post '/api/v1/auth/sso',
           { id_token: SsoTestKeys.mint_id_token }.to_json,
           json_header

      token = JSON.parse(last_response.body)['auth_token']
      scope = FinanceTracker::AuthToken.load(token).scope
      _(scope.can_read?('wallets')).must_equal true
      _(scope.can_write?('wallets')).must_equal true
    end

    it 'BAD: a missing id_token is rejected with 400' do
      post '/api/v1/auth/sso', {}.to_json, json_header

      _(last_response.status).must_equal 400
      _(JSON.parse(last_response.body)['message']).wont_be_nil
    end

    it 'BAD: a malformed token is rejected with 401' do
      post '/api/v1/auth/sso',
           { id_token: 'not-a-jwt' }.to_json,
           json_header

      _(last_response.status).must_equal 401
    end

    it 'BAD: a token with wrong audience is rejected with 401' do
      post '/api/v1/auth/sso',
           { id_token: SsoTestKeys.mint_id_token('aud' => 'wrong-client-id') }.to_json,
           json_header

      _(last_response.status).must_equal 401
    end

    it 'SECURITY: a token signed by a different key is rejected with 401' do
      rogue_key = OpenSSL::PKey::RSA.generate(2048)
      post '/api/v1/auth/sso',
           { id_token: SsoTestKeys.mint_id_token({}, rogue_key) }.to_json,
           json_header

      _(last_response.status).must_equal 401
    end

    it 'SECURITY: an expired token is rejected with 401' do
      expired_token = SsoTestKeys.mint_id_token('exp' => Time.now.to_i - 1)
      post '/api/v1/auth/sso', { id_token: expired_token }.to_json, json_header

      _(last_response.status).must_equal 401
    end
  end
end
