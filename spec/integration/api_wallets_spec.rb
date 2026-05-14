# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Wallet Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
    @req_header = { 'CONTENT_TYPE' => 'application/json' }
    @account_data = {
      'username' => 'wallet.owner',
      'email' => 'wallet.owner@example.com',
      'password' => 'wallet-password',
      'avatar' => 'owner.png'
    }
    @account = FinanceTracker::CreateAccount.call(account_data: @account_data)
  end

  it 'HAPPY: should be able to get wallet for a transaction' do
    wallet = FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: @account.id, method_type: 'cash'))
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(wallet_id: wallet.id)
    )

    get "api/v1/transactions/#{transaction.id}/wallet?current_account_id=#{@account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal wallet.name
  end

  it 'SAD: should return error for unknown transaction wallet' do
    get 'api/v1/transactions/foobar/wallet'
    _(last_response.status).must_equal 404
  end

  it 'SECURITY: should prevent basic SQL injection targeting wallet IDs' do
    FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: @account.id, method_type: 'cash'))
    FinanceTracker::Wallet.create(DATA[:wallets][1].merge(account_id: @account.id, method_type: 'bank_account'))

    get "api/v1/wallets/2%20or%20id%3E?current_account_id=#{@account.id}"

    # deliberately not reporting error -- don't give attacker information
    _(last_response.status).must_equal 404
    _(last_response.body['data']).must_be_nil
  end

  describe 'Creating Wallets' do
    before do
      @wallet_data = DATA[:wallets][1].merge('method_type' => 'bank_account')
    end

    it 'HAPPY: should be able to create new wallet' do
      post 'api/v1/wallets', @wallet_data.merge('current_account_id' => @account.id).to_json, @req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      wallet = FinanceTracker::Wallet.first

      _(created['id']).must_equal wallet.id
      _(created['name']).must_equal @wallet_data['name']
      _(created['method_type']).must_equal 'bank_account'
      _(wallet.account_id).must_equal @account.id
    end

    it 'SAD: should reject create without current account context' do
      post 'api/v1/wallets', @wallet_data.to_json, @req_header
      _(last_response.status).must_equal 401
    end

    it 'SAD: should reject invalid method type' do
      bad_data = @wallet_data.merge('method_type' => 'crypto')
      post 'api/v1/wallets', bad_data.merge('current_account_id' => @account.id).to_json, @req_header
      _(last_response.status).must_equal 400
    end

    it 'SECURITY: should not create wallet with mass assignment' do
      bad_data = @wallet_data.clone
      bad_data['created_at'] = '1900-01-01'
      post 'api/v1/wallets', bad_data.merge('current_account_id' => @account.id).to_json, @req_header
      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end

  describe 'Listing Wallets' do
    it 'HAPPY: returns only current account wallets' do
      other_account = FinanceTracker::CreateAccount.call(
        account_data: {
          'username' => 'someone.else',
          'email' => 'other@example.com',
          'password' => 'other-password',
          'avatar' => 'other.png'
        }
      )

      own_wallet = FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: @account.id))
      FinanceTracker::Wallet.create(DATA[:wallets][1].merge(account_id: other_account.id))

      get "api/v1/wallets?current_account_id=#{@account.id}"
      _(last_response.status).must_equal 200

      result = JSON.parse(last_response.body)
      _(result['data'].count).must_equal 1
      _(result['data'][0]['data']['attributes']['id']).must_equal own_wallet.id
    end
  end
end
