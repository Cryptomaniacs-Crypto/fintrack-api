# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Account Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
    DATA[:transactions].each do |transaction_data|
      FinanceTracker::Transaction.create(transaction_data)
    end
  end

  it 'HAPPY: should be able to get list of all accounts for a transaction' do
    transaction = FinanceTracker::Transaction.first
    DATA[:accounts].each do |account|
      transaction.add_account(account)
    end

    get "api/v1/transactions/#{transaction.id}/accounts"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single account' do
    account_data = DATA[:accounts][1]
    transaction = FinanceTracker::Transaction.first
    account = transaction.add_account(account_data).save # rubocop:disable Sequel/SaveChanges

    get "/api/v1/transactions/#{transaction.id}/accounts/#{account.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['id']).must_equal account.id
    _(result['data']['attributes']['name']).must_equal account_data['name']
  end

  it 'SAD: should return error if unknown account requested' do
    transaction = FinanceTracker::Transaction.first
    get "/api/v1/transactions/#{transaction.id}/accounts/foobar"

    _(last_response.status).must_equal 404
  end

  describe 'Creating Accounts' do
    before do
      @transaction = FinanceTracker::Transaction.first
      @account_data = DATA[:accounts][1]
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'HAPPY: should be able to create new accounts' do
      transaction = FinanceTracker::Transaction.first
      account_data = DATA[:accounts][1]

      req_header = { 'CONTENT_TYPE' => 'application/json' }
      post "api/v1/transactions/#{transaction.id}/accounts", account_data.to_json, req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      account = FinanceTracker::Account.first

      _(created['id']).must_equal account.id
      _(created['name']).must_equal account_data['name']
    end

    it 'SECURITY: should not create accounts with mass assignment' do
      bad_data = @account_data.clone
      bad_data['created_at'] = '1900-01-01'
      post "api/v1/transactions/#{@transaction.id}/accounts", bad_data.to_json, @req_header
      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end
end
