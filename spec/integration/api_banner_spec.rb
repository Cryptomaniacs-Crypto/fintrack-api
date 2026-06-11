# frozen_string_literal: true

require_relative '../spec_helper'
require 'base64'

describe 'Account banner (cover photo) API' do
  include Rack::Test::Methods

  # 1x1 PNG (valid magic bytes)
  PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='

  before do
    wipe_database
    FinanceTracker::Role.find_or_create(name: 'member')
    @alice = FinanceTracker::Account.create(username: 'alice', email: 'a@example.com', password: 'password123')
    @bob   = FinanceTracker::Account.create(username: 'bob',   email: 'b@example.com', password: 'password123')
  end

  let(:json) { { 'CONTENT_TYPE' => 'application/json' } }

  it 'HAPPY: owner uploads, fetches, and removes their banner' do
    put '/api/v1/accounts/alice/banner', { image_base64: PNG, content_type: 'image/png' }.to_json,
        json.merge(auth_header_for(@alice))
    _(last_response.status).must_equal 200
    _(FinanceTracker::Account.first(id: @alice.id).banner?).must_equal true

    get '/api/v1/accounts/alice/banner', nil, auth_header_for(@alice)
    _(last_response.status).must_equal 200
    _(JSON.parse(last_response.body)['image_base64']).must_equal PNG

    delete '/api/v1/accounts/alice/banner', nil, auth_header_for(@alice)
    _(last_response.status).must_equal 200
    _(FinanceTracker::Account.first(id: @alice.id).banner?).must_equal false
  end

  it "SECURITY: cannot set someone else's banner (403)" do
    put '/api/v1/accounts/alice/banner', { image_base64: PNG, content_type: 'image/png' }.to_json,
        json.merge(auth_header_for(@bob))
    _(last_response.status).must_equal 403
    _(FinanceTracker::Account.first(id: @alice.id).banner?).must_equal false
  end

  it 'BAD: a non-image upload (wrong magic bytes) is rejected (400)' do
    put '/api/v1/accounts/alice/banner',
        { image_base64: Base64.strict_encode64('this is not an image'), content_type: 'image/png' }.to_json,
        json.merge(auth_header_for(@alice))
    _(last_response.status).must_equal 400
  end

  it 'BAD: an unauthenticated request is rejected (401)' do
    put '/api/v1/accounts/alice/banner', { image_base64: PNG, content_type: 'image/png' }.to_json, json
    _(last_response.status).must_equal 401
  end
end
