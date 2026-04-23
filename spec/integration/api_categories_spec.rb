# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Category Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
  end

  it 'HAPPY: should be able to get category for a transaction' do
    account = FinanceTracker::Account.create(DATA[:accounts][0])
    category = FinanceTracker::Category.create(DATA[:categories][0])
    transaction = FinanceTracker::Transaction.create(
      DATA[:transactions][0].merge(account_id: account.id, category_id: category.id)
    )

    get "api/v1/transactions/#{transaction.id}/category"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['name']).must_equal category.name
  end

  it 'SAD: should return error for unknown transaction category' do
    get 'api/v1/transactions/foobar/category'
    _(last_response.status).must_equal 404
  end

  describe 'Creating Categories' do
    before do
      @category_data = DATA[:categories][1]
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'HAPPY: should be able to create new category' do
      post 'api/v1/categories', @category_data.to_json, @req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      category = FinanceTracker::Category.first

      _(created['id']).must_equal category.id
      _(created['name']).must_equal @category_data['name']
    end

    it 'SECURITY: should not create category with mass assignment' do
      bad_data = @category_data.clone
      bad_data['created_at'] = '1900-01-01'
      post 'api/v1/categories', bad_data.to_json, @req_header

      _(last_response.status).must_equal 400
      _(last_response.headers['Location']).must_be_nil
    end
  end
end
