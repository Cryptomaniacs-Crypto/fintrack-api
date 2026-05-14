# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Wallet Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
    @account = FinanceTracker::CreateAccount.call(
      account_data: {
        'username' => 'wallet.spec',
        'email' => 'wallet.spec@example.com',
        'password' => 'wallet-spec-password',
        'avatar' => 'wallet.png'
      }
    )
  end

  it 'HAPPY: should be able to get list of all wallets' do
    FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: @account.id))
    FinanceTracker::Wallet.create(DATA[:wallets][1].merge(account_id: @account.id))

    get "api/v1/wallets?current_account_id=#{@account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single wallet' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: @account.id))

    get "/api/v1/wallets/#{wallet.id}?current_account_id=#{@account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal DATA[:wallets][0]['name']
    _(result['data']['attributes']['balance'].to_f).must_equal DATA[:wallets][0]['balance'].to_f
  end

  it 'SAD: should return error if unknown wallet requested' do
    get "/api/v1/wallets/foobar?current_account_id=#{@account.id}"
    _(last_response.status).must_equal 404
  end

  it 'HAPPY: should be able to create new wallet' do
    existing = DATA[:wallets][0].merge('method_type' => 'cash')

    req_header = { 'CONTENT_TYPE' => 'application/json' }
    post 'api/v1/wallets', existing.merge('current_account_id' => @account.id).to_json, req_header
    _(last_response.status).must_equal 201
    _(last_response.headers['Location'].size).must_be :>, 0

    created = JSON.parse(last_response.body)['data']['data']['attributes']
    _(created['name']).must_equal existing['name']
    _(created['method_type']).must_equal existing['method_type']
    _(created['balance'].to_f).must_equal existing['balance'].to_f
  end

  it 'HAPPY: should retrieve correct data from database' do
    wallet_data = DATA[:wallets][1].merge('account_id' => @account.id)
    new_wallet = FinanceTracker::Wallet.create(wallet_data)

    wallet = FinanceTracker::Wallet.find(id: new_wallet.id)
    _(wallet.name).must_equal wallet_data['name']
    _(wallet.method_type).must_equal 'cash'
    _(wallet.account_id).must_equal @account.id
    _(wallet.balance.to_f).must_equal wallet_data['balance'].to_f
  end

  it 'SECURITY: should not use deterministic integers as ID' do
    wallet_data = DATA[:wallets][1].merge(account_id: @account.id)
    new_wallet = FinanceTracker::Wallet.create(wallet_data)
    _(new_wallet.id.is_a?(Numeric)).must_equal false
  end
end
