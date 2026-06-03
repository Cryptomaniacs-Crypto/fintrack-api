# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Wallet Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  def auth_header(account)
    auth_header_for(account)
  end

  it 'HAPPY: should be able to get wallet for a transaction' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(wallet_id: wallet.id)
    )

    get "api/v1/transactions/#{transaction.id}/wallet"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal wallet.name
  end

  it 'SAD: should return error for unknown transaction wallet' do
    get 'api/v1/transactions/foobar/wallet'
    _(last_response.status).must_equal 404
  end

  it 'SECURITY: should prevent basic SQL injection targeting wallet IDs' do
    FinanceTracker::Wallet.create(DATA[:wallets][0])
    FinanceTracker::Wallet.create(DATA[:wallets][1])

    get 'api/v1/wallets/2%20or%20id%3E'

    # deliberately not reporting error -- don't give attacker information
    _(last_response.status).must_equal 404
    _(last_response.body['data']).must_be_nil
  end

  describe 'Creating Wallets' do
    before do
      @wallet_data = DATA[:wallets][1]
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'HAPPY: should be able to create new wallet' do
      post 'api/v1/wallets', @wallet_data.to_json, @req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      wallet = FinanceTracker::Wallet.first

      _(created['id']).must_equal wallet.id
      _(created['name']).must_equal @wallet_data['name']
    end

    it 'HAPPY: should attach the requesting account to the wallet' do
      account = FinanceTracker::CreateAccount.call(
        account_data: {
          'username' => 'wallet.owner',
          'email' => 'wallet.owner@example.com',
          'password' => 'wallet-password',
          'avatar' => 'wallet.png'
        }
      )

      post 'api/v1/wallets', @wallet_data.to_json, @req_header.merge(auth_header(account))
      _(last_response.status).must_equal 201

      wallet = FinanceTracker::Wallet.first
      _(wallet.account_id).must_equal account.id
    end

    it 'SECURITY: should not create wallet with mass assignment' do
      bad_data = @wallet_data.clone
      bad_data['created_at'] = '1900-01-01'
      post 'api/v1/wallets', bad_data.to_json, @req_header
      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end
end
