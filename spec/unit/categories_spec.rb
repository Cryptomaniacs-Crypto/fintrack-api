# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Category Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all categories' do
    FinanceTracker::Category.create(DATA[:categories][0])
    FinanceTracker::Category.create(DATA[:categories][1])

    get 'api/v1/categories'
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single category' do
    category = FinanceTracker::Category.create(DATA[:categories][0])

    get "/api/v1/categories/#{category.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:categories][0]['name']
    _(result['data']['attributes']['description']).must_equal DATA[:categories][0]['description']
  end

  it 'SAD: should return error if unknown category requested' do
    get '/api/v1/categories/foobar'
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new category' do
    existing = DATA[:categories][0]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/categories', existing.to_json, req_header
    _(last_response.status).must_equal 201, last_response.body
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['data']['attributes']
    _(created['name']).must_equal existing['name']
    _(created['description']).must_equal existing['description']
  end

  it 'HAPPY: should be able to get category for a transaction' do
    # wallet MUST be created first
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    category = FinanceTracker::Category.create(DATA[:categories][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(wallet_id: wallet.id, category_id: category.id)
    )

    get "/api/v1/transactions/#{transaction.id}/category"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:categories][0]['name']
  end

  it 'HAPPY: should retrieve correct data from database' do
    category_data = DATA[:categories][1]
    new_category = FinanceTracker::Category.create(category_data)

    category = FinanceTracker::Category.find(id: new_category.id)
    _(category.name).must_equal category_data['name']
    _(category.description).must_equal category_data['description']
  end
end
