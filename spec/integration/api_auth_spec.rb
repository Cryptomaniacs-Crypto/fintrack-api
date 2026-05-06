# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Authentication API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @account_data = { 'username' => 'auth.user', 'email' => 'auth@example.com',
                      'password' => 's3cret-pa55', 'avatar' => 'auth.png' }
    @account = FinanceTracker::CreateAccount.call(account_data: @account_data)
    @req_header = { 'CONTENT_TYPE' => 'application/json' }
  end

  it 'HAPPY: should authenticate valid credentials' do
    creds = { username: @account_data['username'], password: @account_data['password'] }
    post '/api/v1/auth/authentication', creds.to_json, @req_header

    _(last_response.status).must_equal 200

    body = JSON.parse(last_response.body)
    attrs = body['data']['attributes']
    _(body['data']['type']).must_equal 'account'
    _(attrs['id']).must_equal @account.id
    _(attrs['username']).must_equal @account_data['username']
    _(attrs['email']).must_equal @account_data['email']
    _(body['included']['system_roles']).must_be_kind_of Array
  end

  it 'HAPPY: should include assigned roles in the response' do
    FinanceTracker::Role.create(name: 'admin')
    FinanceTracker::AssignRoleToAccount.call(username: @account_data['username'], role_name: 'admin')

    creds = { username: @account_data['username'], password: @account_data['password'] }
    post '/api/v1/auth/authentication', creds.to_json, @req_header

    _(last_response.status).must_equal 200
    body = JSON.parse(last_response.body)
    role_names = body['included']['system_roles'].map { |r| r['name'] }
    _(role_names).must_include 'admin'
  end

  it 'BAD: should reject wrong password with 403' do
    creds = { username: @account_data['username'], password: 'not-the-password' }
    post '/api/v1/auth/authentication', creds.to_json, @req_header

    _(last_response.status).must_equal 403
    body = JSON.parse(last_response.body)
    _(body['message']).wont_be_nil
    _(body['data']).must_be_nil
  end

  it 'BAD: should reject unknown username with 403' do
    creds = { username: 'nosuch.user', password: 'anything' }
    post '/api/v1/auth/authentication', creds.to_json, @req_header

    _(last_response.status).must_equal 403
  end

  it 'SECURITY: should not expose password digest in the response' do
    creds = { username: @account_data['username'], password: @account_data['password'] }
    post '/api/v1/auth/authentication', creds.to_json, @req_header

    body = JSON.parse(last_response.body)
    attrs = body['data']['attributes']
    _(attrs).wont_include 'password'
    _(attrs).wont_include 'password_digest'
    _(attrs).wont_include 'email_secure'
    _(attrs).wont_include 'email_hash'
  end
end
