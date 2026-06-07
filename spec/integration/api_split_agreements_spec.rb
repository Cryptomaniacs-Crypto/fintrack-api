# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Bill Splits API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @alice = FinanceTracker::Account.create(
      username: 'alice',
      email: 'alice@example.com',
      password: 'StrongPass123!'
    )
    @bob = FinanceTracker::Account.create(
      username: 'bob',
      email: 'bob@example.com',
      password: 'StrongPass456!'
    )
    @req_header = { 'CONTENT_TYPE' => 'application/json' }
  end

  # --- Create ---

  it 'creates a bill split for authenticated creator' do
    payload = { recipient_username: 'bob', amount: '75.50', reason_note: 'Dinner at Nobu' }

    post 'api/v1/bill-splits', payload.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 201
    attrs = JSON.parse(last_response.body)['data']['attributes']
    _(attrs['status']).must_equal 'pending'
    _(attrs['amount']).must_equal '75.50'
    _(attrs['reason_note']).must_equal 'Dinner at Nobu'
    _(attrs['creator_id']).must_equal @alice.id
    _(attrs['recipient_id']).must_equal @bob.id
  end

  it 'rejects creation without recipient_username' do
    post 'api/v1/bill-splits', { amount: '50.0', reason_note: 'Coffee' }.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 400
  end

  it 'rejects creation without amount' do
    post 'api/v1/bill-splits', { recipient_username: 'bob', reason_note: 'Coffee' }.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 400
  end

  it 'rejects creation without reason_note' do
    post 'api/v1/bill-splits', { recipient_username: 'bob', amount: '50.0' }.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 400
  end

  it 'rejects creating a split with yourself' do
    post 'api/v1/bill-splits', { recipient_username: 'alice', amount: '10.0', reason_note: 'Oops' }.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 400
  end

  it 'rejects unauthenticated creation' do
    post 'api/v1/bill-splits', { recipient_username: 'bob', amount: '50.0', reason_note: 'Test' }.to_json,
         @req_header

    _(last_response.status).must_equal 401
  end

  # --- View ---

  it 'allows creator to view their bill split' do
    split = create_split(@alice, @bob)

    get "api/v1/bill-splits/#{split.id}", {},
        @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    _(JSON.parse(last_response.body)['data']['attributes']['id']).must_equal split.id
  end

  it 'allows recipient to view the bill split' do
    split = create_split(@alice, @bob)

    get "api/v1/bill-splits/#{split.id}", {},
        @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 200
  end

  it 'forbids outsiders from viewing a bill split' do
    outsider = FinanceTracker::Account.create(
      username: 'mallory',
      email: 'mallory@example.com',
      password: 'Passw0rd!!!'
    )
    split = create_split(@alice, @bob)

    get "api/v1/bill-splits/#{split.id}", {},
        @req_header.merge(auth_header_for(outsider))

    _(last_response.status).must_equal 403
  end

  it 'lists only splits belonging to current account' do
    create_split(@alice, @bob)
    carol = FinanceTracker::Account.create(
      username: 'carol',
      email: 'carol@example.com',
      password: 'StrongPass789!'
    )
    create_split(@carol = carol, @bob)

    get 'api/v1/bill-splits', {}, @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    ids = JSON.parse(last_response.body)['data'].map { |s| s['creator_id'] }
    _(ids).must_equal [@alice.id]
  end

  # --- Agree ---

  it 'allows recipient to agree' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/agree", {}.to_json,
         @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 200
    attrs = JSON.parse(last_response.body)['data']['attributes']
    _(attrs['status']).must_equal 'agreed'
    _(attrs['recipient_agreed_at']).wont_be_nil
  end

  it 'forbids creator from agreeing' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/agree", {}.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 403
  end

  # --- Dispute ---

  it 'allows recipient to dispute with a reason' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/dispute",
         { reason: 'I only had the salad' }.to_json,
         @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 200
    attrs = JSON.parse(last_response.body)['data']['attributes']
    _(attrs['status']).must_equal 'pending'
    _(attrs['dispute_note']).must_equal 'I only had the salad'
  end

  it 'rejects dispute without a reason' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/dispute",
         { reason: '' }.to_json,
         @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 400
  end

  it 'forbids creator from disputing' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/dispute",
         { reason: 'Trying to dispute my own split' }.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 403
  end

  # --- Settle ---

  it 'allows creator to settle' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/settle", {}.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    attrs = JSON.parse(last_response.body)['data']['attributes']
    _(attrs['status']).must_equal 'settled'
    _(attrs['settled_at']).wont_be_nil
  end

  it 'allows recipient to settle' do
    split = create_split(@alice, @bob)

    post "api/v1/bill-splits/#{split.id}/settle", {}.to_json,
         @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 200
    _(JSON.parse(last_response.body)['data']['attributes']['status']).must_equal 'settled'
  end

  it 'rejects double-settle' do
    split = create_split(@alice, @bob)
    split.settle!

    post "api/v1/bill-splits/#{split.id}/settle", {}.to_json,
         @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 400
  end

  # --- Edit ---

  it 'allows creator to edit amount and reason before settlement' do
    split = create_split(@alice, @bob)

    patch "api/v1/bill-splits/#{split.id}",
          { amount: '99.99', reason_note: 'Updated reason' }.to_json,
          @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    attrs = JSON.parse(last_response.body)['data']['attributes']
    _(attrs['amount']).must_equal '99.99'
    _(attrs['reason_note']).must_equal 'Updated reason'
  end

  it 'forbids recipient from editing' do
    split = create_split(@alice, @bob)

    patch "api/v1/bill-splits/#{split.id}",
          { amount: '1.00' }.to_json,
          @req_header.merge(auth_header_for(@bob))

    _(last_response.status).must_equal 403
  end

  it 'forbids editing a settled split' do
    split = create_split(@alice, @bob)
    split.settle!

    patch "api/v1/bill-splits/#{split.id}",
          { amount: '1.00' }.to_json,
          @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 409
  end

  # --- Delete ---

  it 'allows creator to delete a pending split' do
    split = create_split(@alice, @bob)

    delete "api/v1/bill-splits/#{split.id}", {}.to_json,
           @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 200
    _(FinanceTracker::BillSplit.first(id: split.id)).must_be_nil
  end

  it 'forbids deleting a settled split' do
    split = create_split(@alice, @bob)
    split.settle!

    delete "api/v1/bill-splits/#{split.id}", {}.to_json,
           @req_header.merge(auth_header_for(@alice))

    _(last_response.status).must_equal 409
  end

  private

  def create_split(creator, recipient, amount: '50.00', reason: 'Test expense')
    split = FinanceTracker::BillSplit.new(
      creator_id: creator.id,
      recipient_id: recipient.id,
      amount: amount
    )
    split.reason_note = reason
    split.save_changes
    split
  end
end
