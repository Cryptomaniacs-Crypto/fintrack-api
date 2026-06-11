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

  describe 'viewer-scoped serialization (least privilege)' do
    before do
      @id = create_draft['id'] # alice (owner) + bob + carol
      patch "api/v1/bill-splits/#{@id}", {
        tax_percent: '10', service_percent: '5',
        items: [
          { name: 'Pizza', amount: '30', sharer_usernames: %w[alice bob carol] },
          { name: 'Wine',  amount: '20', sharer_usernames: %w[alice bob] },
          { name: 'Cake',  amount: '9',  sharer_usernames: %w[carol] }
        ]
      }.to_json, @json.merge(auth_header_for(@alice))
    end

    it 'gives the owner the full breakdown of everyone' do
      get "api/v1/bill-splits/#{@id}", {}, auth_header_for(@alice)
      _(last_response.status).must_equal 200
      _(attrs['participants'].map { |p| p['username'] }.sort).must_equal %w[alice bob carol]
      _(attrs['items'].first).must_include 'sharer_usernames'
    end

    it 'gives a participant only their own share, itemized, with no one else exposed' do
      get "api/v1/bill-splits/#{@id}", {}, auth_header_for(@bob)
      _(last_response.status).must_equal 200

      # only bob's own row — carol/alice never appear
      _(attrs['participants'].map { |p| p['username'] }).must_equal ['bob']
      _(attrs['viewer_is_owner']).must_equal false

      # bob is on Pizza + Wine, not Cake
      names = attrs['items'].map { |i| i['name'] }.sort
      _(names).must_equal %w[Pizza Wine]

      # itemized share is present; other people's identities are NOT
      pizza = attrs['items'].find { |i| i['name'] == 'Pizza' }
      _(pizza['shared_by_count']).must_equal 3
      _(pizza['your_share']).must_equal '10.0'
      _(pizza).wont_include 'sharer_usernames'

      # the raw response body must not leak carol anywhere
      _(last_response.body).wont_include 'carol'
    end
  end

  describe 'source receipt photo' do
    RECEIPT_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

    before { @id = create_draft['id'] } # alice owner; bob + carol participants

    def upload_receipt(account, base64: RECEIPT_PNG, type: 'image/png')
      post "api/v1/bill-splits/#{@id}/receipt",
           { image_base64: base64, content_type: type }.to_json,
           @json.merge(auth_header_for(account))
    end

    it 'lets the owner upload a receipt and flags has_receipt' do
      upload_receipt(@alice)
      _(last_response.status).must_equal 200

      get "api/v1/bill-splits/#{@id}", {}, auth_header_for(@alice)
      _(attrs['has_receipt']).must_equal true
    end

    it 'lets any participant view the uploaded receipt' do
      upload_receipt(@alice)
      get "api/v1/bill-splits/#{@id}/receipt", {}, auth_header_for(@bob)
      _(last_response.status).must_equal 200
      _(JSON.parse(last_response.body)['image_base64']).must_equal RECEIPT_PNG
    end

    it 'forbids a non-owner participant from uploading' do
      upload_receipt(@bob)
      _(last_response.status).must_equal 403
    end

    it 'rejects an image whose bytes do not match the declared type' do
      upload_receipt(@alice, base64: Base64.strict_encode64('not a png'))
      _(last_response.status).must_equal 400
    end

    it 'lets the owner remove the receipt' do
      upload_receipt(@alice)
      delete "api/v1/bill-splits/#{@id}/receipt", {}, auth_header_for(@alice)
      _(last_response.status).must_equal 200
      get "api/v1/bill-splits/#{@id}", {}, auth_header_for(@alice)
      _(attrs['has_receipt']).must_equal false
    end
  end

  describe 'wallet-backed settlement' do
    # A valid 1x1 PNG (correct magic bytes) for proof-image tests.
    PNG_1PX = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='

    def wallet_for(account, name)
      FinanceTracker::Wallet.create(account_id: account.id, name:, balance: '0', method_type: 'cash')
    end

    def participant_id(username)
      attrs['participants'].find { |p| p['username'] == username }['participant_id']
    end

    before do
      @wa  = wallet_for(@alice, 'Alice Cash')
      @wa2 = wallet_for(@alice, 'Alice Bank')
      @wb  = wallet_for(@bob, 'Bob Cash')
      @id = create_draft['id'] # alice + bob + carol
      patch "api/v1/bill-splits/#{@id}",
            { items: [{ name: 'Meal', amount: '30', sharer_usernames: %w[alice bob carol] }] }.to_json,
            @json.merge(auth_header_for(@alice))
    end

    def send_with_wallet(wallet = @wa)
      post "api/v1/bill-splits/#{@id}/send", { wallet_id: wallet.id }.to_json, @json.merge(auth_header_for(@alice))
    end

    it 'records the owner upfront expense and auto-settles the owner row on send' do
      send_with_wallet
      _(last_response.status).must_equal 200
      _(attrs['status']).must_equal 'pending'
      _(attrs['creator_wallet_id']).must_equal @wa.id
      owner_row = attrs['participants'].find { |p| p['username'] == 'alice' }
      _(owner_row['status']).must_equal 'settled'
      # an expense transaction for the grand total ($30) exists on the owner's wallet
      _(FinanceTracker::Transaction.where(wallet_id: @wa.id).map(&:amount)).must_include '-30.0'
    end

    it 'lets a participant pay from their own wallet (expense recorded)' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay", { wallet_id: @wb.id }.to_json, @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 200
      bob = attrs['participants'].find { |p| p['username'] == 'bob' }
      _(bob['status']).must_equal 'paid'
      _(FinanceTracker::Transaction.where(wallet_id: @wb.id).map(&:amount)).must_include '-10.0'
    end

    it 'rejects paying from a wallet you do not own' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay", { wallet_id: @wa.id }.to_json, @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 400
    end

    it 'requires agreement before paying' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/pay", { wallet_id: @wb.id }.to_json, @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 400
    end

    it 'lets the owner confirm a payment (income recorded) and settles the share' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay", { wallet_id: @wb.id }.to_json, @json.merge(auth_header_for(@bob))
      pid = participant_id('bob')
      post "api/v1/bill-splits/#{@id}/participants/#{pid}/confirm", { wallet_id: @wa2.id }.to_json, @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 200
      bob = attrs['participants'].find { |p| p['username'] == 'bob' }
      _(bob['status']).must_equal 'settled'
      _(FinanceTracker::Transaction.where(wallet_id: @wa2.id).map(&:amount)).must_include '10.0'
    end

    it 'auto-settles the whole bill once every participant is settled' do
      @wc = wallet_for(@carol, 'Carol Cash')
      send_with_wallet
      %i[bob carol].each do |who|
        acct = instance_variable_get("@#{who}")
        wallet = who == :bob ? @wb : @wc
        post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(acct))
        post "api/v1/bill-splits/#{@id}/pay", { wallet_id: wallet.id }.to_json, @json.merge(auth_header_for(acct))
        pid = participant_id(who.to_s)
        post "api/v1/bill-splits/#{@id}/participants/#{pid}/confirm", { wallet_id: @wa.id }.to_json, @json.merge(auth_header_for(@alice))
      end
      _(attrs['status']).must_equal 'settled'
    end

    it 'locks editing once a payment has been made' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay", { wallet_id: @wb.id }.to_json, @json.merge(auth_header_for(@bob))
      patch "api/v1/bill-splits/#{@id}", { tax_percent: '5' }.to_json, @json.merge(auth_header_for(@alice))
      _(last_response.status).must_equal 409
    end

    it 'stores and serves a valid proof image to the owner, hides it from outsiders' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay",
           { wallet_id: @wb.id, proof_base64: PNG_1PX, proof_content_type: 'image/png' }.to_json,
           @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 200
      _(attrs['participants'].find { |p| p['username'] == 'bob' }['has_proof']).must_equal true

      pid = participant_id('bob')
      get "api/v1/bill-splits/#{@id}/participants/#{pid}/proof", {}, auth_header_for(@alice)
      _(last_response.status).must_equal 200
      _(JSON.parse(last_response.body)['image_base64']).must_equal PNG_1PX

      # a non-participant cannot view it
      get "api/v1/bill-splits/#{@id}/participants/#{pid}/proof", {}, auth_header_for(@carol)
      _(last_response.status).must_equal 403
    end

    it 'rejects a proof whose bytes do not match the declared type' do
      send_with_wallet
      post "api/v1/bill-splits/#{@id}/agree", '', @json.merge(auth_header_for(@bob))
      post "api/v1/bill-splits/#{@id}/pay",
           { wallet_id: @wb.id, proof_base64: Base64.strict_encode64('not really a png'), proof_content_type: 'image/png' }.to_json,
           @json.merge(auth_header_for(@bob))
      _(last_response.status).must_equal 400
    end
  end
end
