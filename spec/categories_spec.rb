# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Category Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all categories for a transaction' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    transaction.add_category(DATA[:categories][0])
    transaction.add_category(DATA[:categories][1])

    get "api/v1/transactions/#{transaction.id}/categories"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single category' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    transaction.add_category(DATA[:categories][0])
    category = FinanceTracker::Category.first

    get "/api/v1/transactions/#{transaction.id}/categories/#{category.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['id']).must_equal category.id
    _(result['data']['attributes']['name']).must_equal DATA[:categories][0]['name']
  end

  it 'SAD: should return error if unknown category requested' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])

    get "/api/v1/transactions/#{transaction.id}/categories/foobar"
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new category for a transaction' do
    # transaction = FinanceTracker::Transaction.create(DATA[:transactions][0]).save_changes
    transaction = FinanceTracker::Transaction.create(DATA[:transactions][0])
    existing = DATA[:categories][0]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post "api/v1/transactions/#{transaction.id}/categories", existing.to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['attributes']
    _(created['name']).must_equal existing['name']
  end
end