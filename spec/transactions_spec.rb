# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Transaction Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all transactions' do
    FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    FinanceTracker::Transaction.create(DATA[:transactions][1]).save_changes

    get 'api/v1/transactions'
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single transaction' do
    existing = DATA[:transactions][1]
    FinanceTracker::Transaction.create(existing).save_changes
    id = FinanceTracker::Transaction.first.id

    get "/api/v1/transactions/#{id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['id']).must_equal id
    _(result['data']['attributes']['title']).must_equal existing['title']
  end

  it 'SAD: should return error if unknown transaction requested' do
    get '/api/v1/transactions/foobar'
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new transaction' do
    existing = DATA[:transactions][1]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/transactions', existing.to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['attributes']
    transaction = FinanceTracker::Transaction.first

    _(created['id']).must_equal transaction.id
    _(created['title']).must_equal existing['title']
    _(created['amount']).must_equal existing['amount']
  end
end