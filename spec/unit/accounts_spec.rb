# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Account Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all accounts' do
    FinanceTracker::Account.create(DATA[:accounts][0])
    FinanceTracker::Account.create(DATA[:accounts][1])

    get 'api/v1/accounts'
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single account' do
    account = FinanceTracker::Account.create(DATA[:accounts][0])

    get "/api/v1/accounts/#{account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:accounts][0]['name']
    _(result['data']['attributes']['balance'].to_f).must_equal DATA[:accounts][0]['balance'].to_f
  end

  it 'SAD: should return error if unknown account requested' do
    get '/api/v1/accounts/foobar'
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new account' do
    existing = DATA[:accounts][0]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/accounts', existing.to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['attributes']
    _(created['name']).must_equal existing['name']
    _(created['balance'].to_f).must_equal existing['balance'].to_f
  end

  it 'HAPPY: should retrieve correct data from database' do
    account_data = DATA[:accounts][1]
    account = FinanceTracker::Account.first
    new_account = account.add_account(account_data)

    account = FinanceTracker::Account.find(id:new_account.id)
    _(account.name).must_equal account_data['name']
    _(account.balance.to_f).must_equal account_data['balance'].to_f
  end

  it 'SECURITY: should not use deterministic integers as ID' do
    account_data = DATA[:accounts][1]
    account = FinanceTracker::Account.first
    new_account = account.add_account(account_data)
    _(new_account.id.is_a?(Numeric)).must_equal false
  end
end