# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Account Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all accounts for a transaction' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    transaction.add_account(DATA[:accounts][0])
    transaction.add_account(DATA[:accounts][1])

    get "api/v1/transactions/#{transaction.id}/accounts"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single account' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    transaction.add_account(DATA[:accounts][0])
    account = FinanceTracker::Account.first

    get "/api/v1/transactions/#{transaction.id}/accounts/#{account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['id']).must_equal account.id
    _(result['data']['attributes']['name']).must_equal DATA[:accounts][0]['name']
  end

  it 'SAD: should return error if unknown account requested' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])

    get "/api/v1/transactions/#{transaction.id}/accounts/foobar"
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new account for a transaction' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    existing = DATA[:accounts][0]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post "api/v1/transactions/#{transaction.id}/accounts", existing.to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['attributes']
    _(created['name']).must_equal existing['name']
    _(created['amount']).must_equal existing['amount']
  end
end