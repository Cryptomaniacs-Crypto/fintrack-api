# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Transaction Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all transactions' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    FinanceTracker::Transaction.create(DATA[:transactions][0].merge(wallet_id: wallet.id))
    FinanceTracker::Transaction.create(DATA[:transactions][1].merge(wallet_id: wallet.id))

    get 'api/v1/transactions'
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single transaction' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(wallet_id: wallet.id)
    )

    get "/api/v1/transactions/#{transaction.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['title']).must_equal DATA[:transactions][0]['title']
    _(result['data']['attributes']['amount'].to_f).must_equal DATA[:transactions][0]['amount'].to_f
  end

  it 'SAD: should return error if unknown transaction requested' do
    get '/api/v1/transactions/foobar'
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new transaction' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    new_transaction = DATA[:transactions][0].merge(wallet_id: wallet.id)

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/transactions', new_transaction.to_json, req_header

    _(last_response.status).must_equal 201, last_response.body
  end

  it 'SAD: should return error if creating transaction with invalid wallet' do
    new_transaction = DATA[:transactions][0].merge(wallet_id: 99999)

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/transactions', new_transaction.to_json, req_header
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to get wallet for a transaction' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(wallet_id: wallet.id)
    )

    get "/api/v1/transactions/#{transaction.id}/wallet"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:wallets][0]['name']
  end

  it 'HAPPY: should be able to get category for a transaction' do
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
end
