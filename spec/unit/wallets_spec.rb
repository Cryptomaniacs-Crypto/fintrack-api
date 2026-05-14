# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Wallet Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get list of all wallets' do
    FinanceTracker::Wallet.create(DATA[:wallets][0])
    FinanceTracker::Wallet.create(DATA[:wallets][1])

    get 'api/v1/wallets'
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single wallet' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])

    get "/api/v1/wallets/#{wallet.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:wallets][0]['name']
    _(result['data']['attributes']['balance'].to_f).must_equal DATA[:wallets][0]['balance'].to_f
  end

  it 'SAD: should return error if unknown wallet requested' do
    get '/api/v1/wallets/foobar'
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new wallet' do
    existing = DATA[:wallets][0]

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/wallets', existing.to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['data']['attributes']
    _(created['name']).must_equal existing['name']
    _(created['balance'].to_f).must_equal existing['balance'].to_f
  end

  it 'HAPPY: should retrieve correct data from database' do
    wallet_data = DATA[:wallets][1]
    new_wallet = FinanceTracker::Wallet.create(wallet_data)

    wallet = FinanceTracker::Wallet.find(id: new_wallet.id)
    _(wallet.name).must_equal wallet_data['name']
    _(wallet.balance.to_f).must_equal wallet_data['balance'].to_f
  end

  it 'SECURITY: should not use deterministic integers as ID' do
    wallet_data = DATA[:wallets][1]
    new_wallet = FinanceTracker::Wallet.create(wallet_data)
    _(new_wallet.id.is_a?(Numeric)).must_equal false
  end
end
