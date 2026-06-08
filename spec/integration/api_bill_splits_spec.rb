# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Bill Splits API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @alice = FinanceTracker::Account.create(username: 'alice', email: 'alice@example.com', password: 'StrongPass123!')
    @bob   = FinanceTracker::Account.create(username: 'bob',   email: 'bob@example.com',   password: 'StrongPass456!')
    @carol = FinanceTracker::Account.create(username: 'carol', email: 'carol@example.com', password: 'StrongPass789!')
    @json = { 'CONTENT_TYPE' => 'application/json' }
  end

  # Create a draft and return its parsed attributes envelope.
  def create_draft(creator: @alice, title: 'Dinner', usernames: %w[bob carol])
    post 'api/v1/bill-splits', { title:, participant_usernames: usernames }.to_json,
         @json.merge(auth_header_for(creator))
    JSON.parse(last_response.body).dig('data', 'attributes')
  end

  def attrs = JSON.parse(last_response.body).dig('data', 'attributes')

  describe 'creating a draft' do
    it 'creates a draft that includes the creator as a participant' do
      data = create_draft

      _(last_response.status).must_equal 201
      _(data['status']).must_equal 'draft'
      _(data['title']).must_equal 'Dinner'
      _(data['participants'].map { |p| p['username'] }.sort).must_equal %w[alice bob carol]
    end

    it 'rejects an unknown participant username with 404' do
      post 'api/v1/bill-splits', { title: 'X', participant_usernames: ['ghost'] }.to_json,
           @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 404
    end

    it 'rejects a missing title' do
      post 'api/v1/bill-splits', { participant_usernames: ['bob'] }.to_json,
           @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 400
    end

    it 'rejects a split with no other participants' do
      post 'api/v1/bill-splits', { title: 'Solo', participant_usernames: [] }.to_json,
           @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 400
    end

    it 'requires authentication' do
      post 'api/v1/bill-splits', { title: 'X', participant_usernames: ['bob'] }.to_json, @json
      _(last_response.status).must_equal 401
    end
  end

  describe 'dishes and the per-person breakdown' do
    before { @id = create_draft['id'] }

    it 'splits each dish equally among its sharers and applies tax/service' do
      patch "api/v1/bill-splits/#{@id}", {
        tax_percent: '10', service_percent: '5',
        items: [
          { name: 'Pizza', amount: '30', sharer_usernames: %w[alice bob carol] },
          { name: 'Wine',  amount: '20', sharer_usernames: %w[alice bob] },
          { name: 'Cake',  amount: '9',  sharer_usernames: %w[carol] }
        ]
      }.to_json, @json.merge(auth_header_for(@alice))

      _(last_response.status).must_equal 200
      rows = attrs['participants'].to_h { |p| [p['username'], p] }
      _(rows['alice']['total']).must_equal '23.0'
      _(rows['bob']['total']).must_equal '23.0'
      _(rows['carol']['total']).must_equal '21.85'
      _(attrs['grand_total']).must_equal '67.85'
    end

    it 'rejects a dish with no sharers' do
      patch "api/v1/bill-splits/#{@id}", { items: [{ name: 'Bread', amount: '5', sharer_usernames: [] }] }.to_json,
            @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 400
    end

    it 'forbids a non-creator from editing' do
      patch "api/v1/bill-splits/#{@id}", { tax_percent: '10' }.to_json, @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 403
    end
  end

  describe 'lifecycle' do
    before do
      @id = create_draft['id']
      patch "api/v1/bill-splits/#{@id}",
            { items: [{ name: 'Meal', amount: '30', sharer_usernames: %w[alice bob carol] }] }.to_json,
            @json.merge(auth_header_for(@alice))
    end

    def send_bill = post("api/v1/bill-splits/#{@id}/send", '', @json.merge(auth_header_for(@alice)))

    it 'sends the draft to participants' do
      send_bill
      _(last_response.status).must_equal 200
      _(attrs['status']).must_equal 'pending'
    end

    it 'refuses to send a draft with no dishes' do
      empty_id = create_draft(title: 'Empty')['id']
      post "api/v1/bill-splits/#{empty_id}/send", '', @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 400
    end

    it 'lets a participant agree to their share' do
      send_bill
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 200
      _(attrs['participants'].find { |p| p['username'] == 'bob' }['status']).must_equal 'agreed'
    end

    it 'lets a participant reject with a note and disputes the bill' do
      send_bill
      post "api/v1/bill-splits/#{@id}/reject", { reason: 'I did not order this' }.to_json,
           @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 200
      _(attrs['status']).must_equal 'disputed'
      bob = attrs['participants'].find { |p| p['username'] == 'bob' }
      _(bob['status']).must_equal 'rejected'
      _(bob['reject_note']).must_equal 'I did not order this'
    end

    it 'requires a reason to reject' do
      send_bill
      post "api/v1/bill-splits/#{@id}/reject", { reason: '' }.to_json, @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 400
    end

    it 'resets every agreement to pending when the owner edits after a dispute' do
      send_bill
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@carol))
      post "api/v1/bill-splits/#{@id}/reject", { reason: 'wrong' }.to_json, @json.merge(auth_header_for(@bob))

      patch "api/v1/bill-splits/#{@id}",
            { items: [{ name: 'Meal', amount: '30', sharer_usernames: %w[alice bob carol] }] }.to_json,
            @json.merge(auth_header_for(@alice))
      _(attrs['participants'].map { |p| p['status'] }.uniq).must_equal ['pending']
    end

    it 'settles the bill as creator and then locks edits' do
      send_bill
      post "api/v1/bill-splits/#{@id}/settle", '', @json.merge(auth_header_for(@alice))
      _(attrs['status']).must_equal 'settled'

      patch "api/v1/bill-splits/#{@id}", { tax_percent: '5' }.to_json, @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 409
    end
  end

  describe 'authorization and listing' do
    it 'hides a bill from non-participants with 403' do
      id = create_draft(usernames: ['bob'])['id'] # alice + bob only
      get "api/v1/bill-splits/#{id}", {}, auth_header_for(@carol)
      _(last_response.status).must_equal 403
    end

    it 'forbids writes with a read-only token' do
      read_only = auth_header_for(@alice, scope: FinanceTracker::AuthScope::READ_ONLY)
      post 'api/v1/bill-splits', { title: 'X', participant_usernames: ['bob'] }.to_json,
           @json.merge(read_only)
      _(last_response.status).must_equal 403
    end

    it 'lists splits where the account participates' do
      create_draft(usernames: ['bob'])
      get 'api/v1/bill-splits', {}, auth_header_for(@bob)
      _(last_response.status).must_equal 200
      _(JSON.parse(last_response.body)['data'].size).must_equal 1
    end
  end
end
