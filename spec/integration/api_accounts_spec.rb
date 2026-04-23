# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Account Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get account for a transaction' do
    account = FinanceTracker::Account.create(DATA[:accounts][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(account_id: account.id)
    )

    get "api/v1/transactions/#{transaction.id}/account"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal account.name
  end

  it 'SAD: should return error for unknown transaction account' do
    get 'api/v1/transactions/foobar/account'
    _(last_response.status).must_equal 404
  end

  describe 'Creating Accounts' do
    before do
      @account_data = DATA[:accounts][1]
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'HAPPY: should be able to create new account' do
      post 'api/v1/accounts', @account_data.to_json, @req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      account = FinanceTracker::Account.first

      _(created['id']).must_equal account.id
      _(created['name']).must_equal @account_data['name']
    end

    it 'SECURITY: should not create account with mass assignment' do
      bad_data = @account_data.clone
      bad_data['created_at'] = '1900-01-01'
      post 'api/v1/accounts', bad_data.to_json, @req_header
      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end
end
