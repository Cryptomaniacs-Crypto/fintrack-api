# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Account API' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  let(:account_data) do
    { 'username' => 'jane.doe', 'email' => 'jane@example.com',
      'password' => 's3cret-pa55', 'avatar' => 'jane.png' }
  end

  describe 'Account information' do
    it 'HAPPY: should be able to get details of a single account by username' do
      FinanceTracker::CreateAccount.call(account_data:)

      get "/api/v1/accounts/#{account_data['username']}"
      _(last_response.status).must_equal 200

      result = JSON.parse last_response.body
      _(result['data']['attributes']['username']).must_equal account_data['username']
      _(result['data']['attributes']['email']).must_equal account_data['email']
    end

    it 'SAD: should return 404 for unknown username' do
      get '/api/v1/accounts/nosuchuser'
      _(last_response.status).must_equal 404
    end

    it 'SECURITY: should not expose password digest or hash columns over the API' do
      FinanceTracker::CreateAccount.call(account_data:)

      get "/api/v1/accounts/#{account_data['username']}"
      attrs = JSON.parse(last_response.body)['data']['attributes']

      _(attrs).wont_include 'password'
      _(attrs).wont_include 'password_digest'
      _(attrs).wont_include 'email_secure'
      _(attrs).wont_include 'email_hash'
    end
  end

  describe 'Searching by email' do
    it 'HAPPY: should find account by email via HMAC lookup' do
      FinanceTracker::CreateAccount.call(account_data:)

      get "/api/v1/accounts?email=#{account_data['email']}"
      _(last_response.status).must_equal 200

      result = JSON.parse last_response.body
      _(result['data']['attributes']['username']).must_equal account_data['username']
    end

    it 'SAD: should return 404 if email not found' do
      FinanceTracker::CreateAccount.call(account_data:)

      get '/api/v1/accounts?email=nobody@example.com'
      _(last_response.status).must_equal 404
    end

    it 'SAD: should return 400 if email param missing' do
      get '/api/v1/accounts'
      _(last_response.status).must_equal 400
    end
  end

  describe 'Account Creation' do
    let(:req_header) { { 'CONTENT_TYPE' => 'application/json' } }

    it 'HAPPY: should create a new account' do
      post 'api/v1/accounts', account_data.to_json, req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['attributes']
      account = FinanceTracker::Account.first

      _(created['id']).must_equal account.id
      _(created['username']).must_equal account_data['username']
      _(account.password?(account_data['password'])).must_equal true
      _(account.password?('not_really_the_password')).must_equal false
    end

    it 'SECURITY: should reject mass-assignment of illegal attributes' do
      bad_data = account_data.merge('created_at' => '1900-01-01')
      post 'api/v1/accounts', bad_data.to_json, req_header

      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end

    it 'SAD: should reject duplicate username with 409' do
      FinanceTracker::CreateAccount.call(account_data:)

      post 'api/v1/accounts', account_data.to_json, req_header
      _(last_response.status).must_equal 409
    end
  end

  describe 'Account Role Associations' do
    let(:req_header) { { 'CONTENT_TYPE' => 'application/json' } }

    it 'HAPPY: should assign a role to an account through many-to-many join table' do
      FinanceTracker::CreateAccount.call(account_data:)
      FinanceTracker::Role.create(name: 'member')

      post "api/v1/accounts/#{account_data['username']}/roles/member", {}.to_json, req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location']).must_equal("api/v1/accounts/#{account_data['username']}/roles/member")

      role_names = FinanceTracker::Account.first(username: account_data['username']).system_roles.map(&:name)
      _(role_names).must_equal ['member']
    end

    it 'HAPPY: should list roles assigned to an account' do
      FinanceTracker::CreateAccount.call(account_data:)
      FinanceTracker::Role.create(name: 'admin')
      FinanceTracker::Role.create(name: 'member')
      FinanceTracker::AssignRoleToAccount.call(username: account_data['username'], role_name: 'admin')
      FinanceTracker::AssignRoleToAccount.call(username: account_data['username'], role_name: 'member')

      get "api/v1/accounts/#{account_data['username']}/roles"
      _(last_response.status).must_equal 200

      role_names = JSON.parse(last_response.body)['data'].map { |role| role['name'] }.sort
      _(role_names).must_equal %w[admin member]
    end

    it 'SAD: should return 409 when assigning a duplicate role' do
      FinanceTracker::CreateAccount.call(account_data:)
      FinanceTracker::Role.create(name: 'member')
      FinanceTracker::AssignRoleToAccount.call(username: account_data['username'], role_name: 'member')

      post "api/v1/accounts/#{account_data['username']}/roles/member", {}.to_json, req_header
      _(last_response.status).must_equal 409
    end
  end
end
