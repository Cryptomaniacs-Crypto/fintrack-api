# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Auth Scopes' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  let(:account_data) do
    { 'username' => 'scope.user', 'email' => 'scope@example.com',
      'password' => 's3cret-pa55', 'avatar' => 'a.png' }
  end
  let(:json_header) { { 'CONTENT_TYPE' => 'application/json' } }

  def create_account
    FinanceTracker::CreateAccount.call(account_data:)
  end

  describe 'Login session token' do
    it 'HAPPY: login returns a FULL-scope auth_token' do
      create_account
      post '/api/v1/auth/authentication',
           { username: account_data['username'], password: account_data['password'] }.to_json,
           json_header
      _(last_response.status).must_equal 200

      token = JSON.parse(last_response.body)['auth_token']
      _(token).wont_be_nil
      _(FinanceTracker::AuthToken.load(token).scope.can_write?('wallets')).must_equal true
    end

    it 'SECURITY: a present-but-invalid bearer token is rejected with 401' do
      get '/api/v1/wallets', nil, { 'HTTP_AUTHORIZATION' => 'Bearer garbage-token' }
      _(last_response.status).must_equal 401
    end
  end

  describe 'Account API key (limited scope)' do
    it 'HAPPY: self-view hands back a READ_ONLY auth_token' do
      account = create_account
      get "/api/v1/accounts/#{account_data['username']}", nil, auth_header_for(account)
      _(last_response.status).must_equal 200

      api_key = JSON.parse(last_response.body)['auth_token']
      _(api_key).wont_be_nil
      _(FinanceTracker::AuthToken.load(api_key).scope.to_s).must_equal FinanceTracker::AuthScope::READ_ONLY
    end

    it 'HAPPY: anonymous view returns account data but no API key' do
      create_account
      get "/api/v1/accounts/#{account_data['username']}"
      _(last_response.status).must_equal 200

      body = JSON.parse(last_response.body)
      _(body['data']['attributes']['username']).must_equal account_data['username']
      _(body['auth_token']).must_be_nil
    end
  end

  describe 'Scope enforcement on writes' do
    it 'SECURITY: a READ_ONLY token cannot create a wallet (403)' do
      account = create_account
      post '/api/v1/wallets', DATA[:wallets][1].to_json,
           json_header.merge(auth_header_for(account, scope: FinanceTracker::AuthScope::READ_ONLY))
      _(last_response.status).must_equal 403
    end

    it 'HAPPY: a FULL token can create a wallet (201)' do
      account = create_account
      post '/api/v1/wallets', DATA[:wallets][1].to_json,
           json_header.merge(auth_header_for(account))
      _(last_response.status).must_equal 201
    end

    it 'HAPPY: a READ_ONLY token can still read wallets' do
      account = create_account
      get '/api/v1/wallets', nil, auth_header_for(account, scope: FinanceTracker::AuthScope::READ_ONLY)
      _(last_response.status).must_equal 200
    end
  end
end
