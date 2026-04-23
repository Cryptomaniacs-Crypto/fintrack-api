# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Test Category Handling' do
  include Rack::Test::Methods

  before do
    wipe_database
    DATA[:transactions].each do |transaction_data|
      FinanceTracker::Transaction.create(transaction_data)
    end
  end

  it 'HAPPY: should be able to get list of all categories for a transaction' do
    transaction = FinanceTracker::Transaction.first
    DATA[:categories].each do |category|
      transaction.add_category(category)
    end

    get "api/v1/transactions/#{transaction.id}/categories"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data'].count).must_equal 2
  end

  it 'HAPPY: should be able to get details of a single category' do
    category_data = DATA[:categories][1]
    transaction = FinanceTracker::Transaction.first
    category = transaction.add_category(category_data).save # rubocop:disable Sequel/SaveChanges

    get "/api/v1/transactions/#{transaction.id}/categories/#{category.id}"
    _(last_response.status).must_equal 200

    result = JSON.parse last_response.body
    _(result['data']['attributes']['id']).must_equal category.id
    _(result['data']['attributes']['name']).must_equal category_data['name']
  end

  it 'SAD: should return error if unknown category requested' do
    transaction = FinanceTracker::Transaction.first
    get "/api/v1/transactions/#{transaction.id}/categories/foobar"

    _(last_response.status).must_equal 404
  end

  describe 'Creating Categories' do
    before do
      @transaction = FinanceTracker::Transaction.first
      @category_data = DATA[:categories][1]
      @req_header = { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'HAPPY: should be able to create new categories' do
      transaction = FinanceTracker::Transaction.first
      category_data = DATA[:categories][1]

      req_header = { 'CONTENT_TYPE' => 'application/json' }
      post "api/v1/transactions/#{transaction.id}/categories", category_data.to_json, req_header
      _(last_response.status).must_equal 201
      _(last_response.headers['Location'].size).must_be :>, 0

      created = JSON.parse(last_response.body)['data']['data']['attributes']
      category = FinanceTracker::Category.first

      _(created['id']).must_equal category.id
      _(created['name']).must_equal category_data['name']
    end

    it 'SECURITY: should not create categories with mass assignment' do
      bad_data = @category_data.clone
      bad_data['created_at'] = '1900-01-01'
      post "api/v1/transactions/#{@transaction.id}/categories", bad_data.to_json, @req_header

      _(last_response.status).must_equal 400
      _(llast_response.headers['Location']).must_be_nil
    end
  end
end
