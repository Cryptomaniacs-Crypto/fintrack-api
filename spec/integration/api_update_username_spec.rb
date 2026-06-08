# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Update username API' do
  include Rack::Test::Methods

  before do
    wipe_database
    FinanceTracker::Role.find_or_create(name: 'member')
    @alice = FinanceTracker::Account.create(username: 'alice', email: 'alice@example.com', password: 'password123')
    @bob   = FinanceTracker::Account.create(username: 'bobby', email: 'bob@example.com',   password: 'password123')
  end

  let(:json_header) { { 'CONTENT_TYPE' => 'application/json' } }

  it 'HAPPY: owner renames their own account' do
    put '/api/v1/accounts/alice', { username: 'alice.new' }.to_json,
        json_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    _(JSON.parse(last_response.body)['data']['attributes']['username']).must_equal 'alice.new'
    _(FinanceTracker::Account.first(id: @alice.id).username).must_equal 'alice.new'
  end

  it 'SECURITY: cannot rename someone else (403)' do
    put '/api/v1/accounts/alice', { username: 'hacked' }.to_json,
        json_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 403
    _(FinanceTracker::Account.first(id: @alice.id).username).must_equal 'alice'
  end

  it 'SECURITY: a READ_ONLY token cannot rename (403)' do
    put '/api/v1/accounts/alice', { username: 'alice.new' }.to_json,
        json_header.merge(auth_header_for(@alice, scope: FinanceTracker::AuthScope::READ_ONLY))

    _(last_response.status).must_equal 403
  end

  it 'BAD: a username already taken is rejected (409)' do
    put '/api/v1/accounts/alice', { username: 'bobby' }.to_json,
        json_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 409
  end

  it 'BAD: an invalid-format username is rejected (400)' do
    put '/api/v1/accounts/alice', { username: 'ab' }.to_json, json_header.merge(auth_header_for(@alice))
    _(last_response.status).must_equal 400

    put '/api/v1/accounts/alice', { username: 'has spaces!' }.to_json, json_header.merge(auth_header_for(@alice))
    _(last_response.status).must_equal 400
  end

  it 'BAD: an unauthenticated request is rejected (401)' do
    put '/api/v1/accounts/alice', { username: 'whatever' }.to_json, json_header

    _(last_response.status).must_equal 401
  end
end
