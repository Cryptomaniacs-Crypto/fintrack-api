# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Friends API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @alice = FinanceTracker::Account.create(username: 'alice', email: 'alice@example.com', password: 'StrongPass123!')
    @bob   = FinanceTracker::Account.create(username: 'bob',   email: 'bob@example.com',   password: 'StrongPass456!')
    @carol = FinanceTracker::Account.create(username: 'carol', email: 'carol@example.com', password: 'StrongPass789!')
    @json = { 'CONTENT_TYPE' => 'application/json' }
  end

  def add_friend(username, account: @alice, headers: {})
    post 'api/v1/friends', { username: }.to_json, @json.merge(auth_header_for(account)).merge(headers)
  end

  describe 'listing friends' do
    it 'starts empty' do
      get 'api/v1/friends', {}, auth_header_for(@alice)
      _(last_response.status).must_equal 200
      _(JSON.parse(last_response.body)['data']).must_equal []
    end

    it 'returns saved friends as account envelopes' do
      add_friend('bob')
      get 'api/v1/friends', {}, auth_header_for(@alice)

      usernames = JSON.parse(last_response.body)['data'].map { |f| f.dig('attributes', 'username') }
      _(usernames).must_equal %w[bob]
    end

    it 'requires authentication' do
      get 'api/v1/friends', {}, @json
      _(last_response.status).must_equal 401
    end
  end

  describe 'adding a friend' do
    it 'adds another account by username' do
      add_friend('bob')
      _(last_response.status).must_equal 201
      _(JSON.parse(last_response.body).dig('data', 'attributes', 'username')).must_equal 'bob'
      _(@alice.reload.friends.map(&:username)).must_equal %w[bob]
    end

    it 'is one-way: adding bob does not add alice to bob' do
      add_friend('bob')
      _(@bob.reload.friends).must_equal []
    end

    # Regression: friends_dataset joins accounts + friendships (both have an `id`
    # column), so the duplicate check must qualify the column or sqlite raises
    # "ambiguous column name: id".
    it 'rejects a duplicate friend with 409' do
      add_friend('bob')
      add_friend('bob')
      _(last_response.status).must_equal 409
      _(@alice.reload.friends.map(&:username)).must_equal %w[bob]
    end

    it 'rejects adding yourself with 422' do
      add_friend('alice')
      _(last_response.status).must_equal 422
    end

    it 'rejects an unknown username with 404' do
      add_friend('ghost')
      _(last_response.status).must_equal 404
    end

    it 'requires authentication' do
      post 'api/v1/friends', { username: 'bob' }.to_json, @json
      _(last_response.status).must_equal 401
    end

    it 'forbids a READ_ONLY token from adding a friend' do
      header = auth_header_for(@alice, scope: FinanceTracker::AuthScope::READ_ONLY)
      post 'api/v1/friends', { username: 'bob' }.to_json, @json.merge(header)
      _(last_response.status).must_equal 403
      _(@alice.reload.friends).must_equal []
    end
  end

  describe 'removing a friend' do
    before { add_friend('bob') }

    it 'removes a saved friend' do
      delete 'api/v1/friends/bob', {}, auth_header_for(@alice)
      _(last_response.status).must_equal 200
      _(@alice.reload.friends).must_equal []
    end

    it 'returns 404 when the username is not on the list' do
      delete 'api/v1/friends/carol', {}, auth_header_for(@alice)
      _(last_response.status).must_equal 404
    end

    it 'returns 404 for an unknown username' do
      delete 'api/v1/friends/ghost', {}, auth_header_for(@alice)
      _(last_response.status).must_equal 404
    end

    it 'requires authentication' do
      delete 'api/v1/friends/bob', {}, @json
      _(last_response.status).must_equal 401
    end

    it 'forbids a READ_ONLY token from removing a friend' do
      header = auth_header_for(@alice, scope: FinanceTracker::AuthScope::READ_ONLY)
      delete 'api/v1/friends/bob', {}, header
      _(last_response.status).must_equal 403
      _(@alice.reload.friends.map(&:username)).must_equal %w[bob]
    end
  end
end
