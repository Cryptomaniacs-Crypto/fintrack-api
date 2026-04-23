# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Transaction Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  describe 'Getting transactions' do
    it 'HAPPY: should be able to get list of all transactions' do
      account = FinanceTracker::Account.create(DATA[:accounts][0])
      FinanceTracker::Transaction.create(DATA[:transactions][0].merge(account_id: account.id)).save_changes
      FinanceTracker::Transaction.create(DATA[:transactions][1].merge(account_id: account.id)).save_changes

      get 'api/v1/transactions'
      _(last_response.status).must_equal 200

      result = JSON.parse last_response.body
      _(result['data'].count).must_equal 2
    end

    it 'HAPPY: should be able to get details of a single transaction' do
      existing_transaction = DATA[:transactions][1]
      account = FinanceTracker::Account.create(DATA[:accounts][0])
      FinanceTracker::Transaction.create(existing_transaction.merge(account_id: account.id)).save_changes
      id = FinanceTracker::Transaction.first.id

      get "/api/v1/transactions/#{id}"
      _(last_response.status).must_equal 200

      result = JSON.parse last_response.body
      _(result['data']['attributes']['id']).must_equal id
      _(result['data']['attributes']['title']).must_equal existing_transaction['title']
    end

    it 'SAD: should return error if unknown transaction requested' do
      get '/api/v1/transactions/foobar'

      _(last_response.status).must_equal 404
    end

    it 'SECURITY: should prevent basic SQL injection targeting IDs' do
      account = FinanceTracker::Account.create(DATA[:accounts][0])
      FinanceTracker::Transaction.create(
        DATA[:transactions][0].merge(account_id: account.id, title: 'First Transaction')
      )
      FinanceTracker::Transaction.create(
        DATA[:transactions][1].merge(account_id: account.id, title: 'Second Transaction')
      )
      get 'api/v1/transactions/2%20or%20id%3E'

      # deliberately not reporting error -- don't give attacker information
      _(last_response.status).must_equal 404
      _(last_response.body['data']).must_be_nil
    end
  end

  describe 'Creating New Transactions' do
    before do
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
      @transaction_data = DATA[:transactions][1]
    end


    it 'HAPPY: should be able to create new transactions' do
      existing_transaction = DATA[:transactions][1]
      account = FinanceTracker::Account.create(DATA[:accounts][0])
      payload = existing_transaction.merge(account_id: account.id)

      req_header = { 'CONTENT_TYPE' => 'application/json' }
      post 'api/v1/transactions', payload.to_json, req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      transaction = FinanceTracker::Transaction.first

      _(created['id']).must_equal transaction.id
      _(created['title']).must_equal existing_transaction['title']
      _(created['amount'].to_f).must_equal existing_transaction['amount'].to_f
    end

    it 'SECURITY: should not create transaction with mass assignment' do
      account = FinanceTracker::Account.create(DATA[:accounts][0])
      bad_data = @transaction_data.clone
      bad_data['created_at'] = '1900-01-01'
      bad_data['account_id'] = account.id
      post 'api/v1/transactions', bad_data.to_json, @req_header
      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end
end
