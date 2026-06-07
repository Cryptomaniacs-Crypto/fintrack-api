# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Split agreements API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @account_one = FinanceTracker::Account.create(
      username: 'alice',
      email: 'alice@example.com',
      password: 'StrongPass123!'
    )
    @account_two = FinanceTracker::Account.create(
      username: 'bob',
      email: 'bob@example.com',
      password: 'StrongPass456!'
    )
    @req_header = { 'CONTENT_TYPE' => 'application/json' }
  end

  it 'creates a split agreement for authenticated user' do
    payload = {
      participants: [
        { name: 'alice', amount: '50.0', total: '57.5' },
        { name: 'bob', amount: '50.0', total: '57.5' }
      ],
      tax_percent: '10.0',
      service_percent: '5.0',
      grand_total: '115.0'
    }

    post 'api/v1/split-agreements', payload.to_json,
         @req_header.merge(auth_header_for(@account_one))

    _(last_response.status).must_equal 201
    result = JSON.parse(last_response.body)
    attrs = result['data']['attributes']
    _(attrs['status']).must_equal 'pending'
    _(attrs['initiator_username']).must_equal 'alice'
    _(attrs['participants'].count).must_equal 2
  end

  it 'allows initiator to create agreement without being listed as participant' do
    payload = {
      participants: [
        { name: 'bob', amount: '50.0', total: '57.5' },
        { name: 'carol', amount: '50.0', total: '57.5' }
      ],
      tax_percent: '10.0',
      service_percent: '5.0',
      grand_total: '115.0'
    }

    post 'api/v1/split-agreements', payload.to_json,
         @req_header.merge(auth_header_for(@account_one))

    _(last_response.status).must_equal 201
    result = JSON.parse(last_response.body)
    attrs = result['data']['attributes']
    _(attrs['initiator_username']).must_equal 'alice'
    _(attrs['participants'].map { |p| p['name'] }).must_equal %w[bob carol]
  end

  it 'allows participants to agree and mark paid' do
    agreement = FinanceTracker::SplitAgreement.create(
      initiator_account_id: @account_one.id,
      initiator_username: 'alice',
      participants_json: JSON.generate([
                                         { 'name' => 'alice', 'amount' => '50.0', 'agreed' => false, 'paid' => false },
                                         { 'name' => 'bob', 'amount' => '50.0', 'agreed' => false, 'paid' => false }
                                       ]),
      tax_percent: '10.0',
      service_percent: '5.0',
      grand_total: '115.0',
      status: 'pending'
    )

    post "api/v1/split-agreements/#{agreement.id}/agree", {}.to_json,
         @req_header.merge(auth_header_for(@account_one))
    _(last_response.status).must_equal 200

    post "api/v1/split-agreements/#{agreement.id}/agree", {}.to_json,
         @req_header.merge(auth_header_for(@account_two))
    _(last_response.status).must_equal 200
    agreed = JSON.parse(last_response.body)
    _(agreed['data']['attributes']['status']).must_equal 'agreed'

    post "api/v1/split-agreements/#{agreement.id}/mark-paid", {}.to_json,
         @req_header.merge(auth_header_for(@account_one))
    _(last_response.status).must_equal 200

    post "api/v1/split-agreements/#{agreement.id}/mark-paid", {}.to_json,
         @req_header.merge(auth_header_for(@account_two))
    _(last_response.status).must_equal 200
    paid = JSON.parse(last_response.body)
    _(paid['data']['attributes']['status']).must_equal 'paid'
  end

  it 'prevents non-participants from agreeing' do
    outsider = FinanceTracker::Account.create(
      username: 'mallory',
      email: 'mallory@example.com',
      password: 'StrongPass789!'
    )

    agreement = FinanceTracker::SplitAgreement.create(
      initiator_account_id: @account_one.id,
      initiator_username: 'alice',
      participants_json: JSON.generate([
                                         { 'name' => 'alice', 'amount' => '50.0', 'agreed' => false, 'paid' => false },
                                         { 'name' => 'bob', 'amount' => '50.0', 'agreed' => false, 'paid' => false }
                                       ]),
      tax_percent: '10.0',
      service_percent: '5.0',
      grand_total: '115.0',
      status: 'pending'
    )

    post "api/v1/split-agreements/#{agreement.id}/agree", {}.to_json,
         @req_header.merge(auth_header_for(outsider))

    _(last_response.status).must_equal 403
  end

  it 'allows initiator to finalize when all agreed and no dispute' do
    agreement = FinanceTracker::SplitAgreement.create(
      initiator_account_id: @account_one.id,
      initiator_username: 'alice',
      participants_json: JSON.generate([
                                         { 'name' => 'alice', 'amount' => '50.0', 'agreed' => true, 'paid' => true },
                                         { 'name' => 'bob', 'amount' => '50.0', 'agreed' => true, 'paid' => true }
                                       ]),
      tax_percent: '10.0',
      service_percent: '5.0',
      grand_total: '115.0',
      status: 'paid'
    )

    post "api/v1/split-agreements/#{agreement.id}/finalize", {}.to_json,
         @req_header.merge(auth_header_for(@account_one))

    _(last_response.status).must_equal 200
    finalized = JSON.parse(last_response.body)
    _(finalized['data']['attributes']['status']).must_equal 'finalized'
  end
end
