# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Atomic Transfers API' do
  include Rack::Test::Methods

  before do
    wipe_database
    @alice = FinanceTracker::Account.create(username: 'alice', email: 'alice@example.com', password: 'StrongPass123!')
    @bob   = FinanceTracker::Account.create(username: 'bob',   email: 'bob@example.com',   password: 'StrongPass456!')
    @from  = FinanceTracker::Wallet.create(account_id: @alice.id, name: 'Cash',    method_type: 'cash', balance: 500)
    @to    = FinanceTracker::Wallet.create(account_id: @alice.id, name: 'Savings', method_type: 'bank', balance: 0)
    @json  = { 'CONTENT_TYPE' => 'application/json' }
  end

  def transfer_body(overrides = {})
    {
      wallet_id: @from.id,
      to_wallet_id: @to.id,
      title: 'Rent pot',
      amount: '100',
      transaction_date: '2026-06-14'
    }.merge(overrides)
  end

  def post_transfer(body = transfer_body, account: @alice)
    post 'api/v1/transfers', body.to_json, @json.merge(auth_header_for(account))
  end

  describe 'happy path' do
    it 'creates an expense leg and an income leg with matching magnitude' do
      post_transfer
      _(last_response.status).must_equal 201, last_response.body

      _(FinanceTracker::Transaction.count).must_equal 2
      expense = FinanceTracker::Transaction.first(wallet_id: @from.id)
      income  = FinanceTracker::Transaction.first(wallet_id: @to.id)

      _(expense.amount.to_f).must_equal(-100.0)
      _(income.amount.to_f).must_equal 100.0
      _(expense.title).must_equal 'Transfer → Rent pot'
      _(income.title).must_equal 'Transfer ← Rent pot'
    end
  end

  describe 'atomicity' do
    it 'rolls back the source leg when the destination leg fails' do
      # Make the SECOND Transaction.create (the income leg) blow up, leaving the
      # already-created expense leg to be rolled back by the surrounding
      # DB.transaction. Restored in ensure so the rest of the suite is untouched.
      singleton = FinanceTracker::Transaction.singleton_class
      original  = singleton.instance_method(:create)
      calls     = 0
      singleton.send(:define_method, :create) do |*args, &blk|
        calls += 1
        raise Sequel::DatabaseError, 'simulated failure on second leg' if calls == 2

        original.bind(self).call(*args, &blk)
      end

      begin
        post_transfer
      ensure
        singleton.send(:define_method, :create, original)
      end

      # The first leg committed nothing: a partial transfer must be impossible.
      _(last_response.status).must_equal 500
      _(FinanceTracker::Transaction.count).must_equal 0
    end
  end

  describe 'validation and authorization' do
    it 'rejects a transfer to the same wallet with 422' do
      post_transfer(transfer_body(to_wallet_id: @from.id))
      _(last_response.status).must_equal 422
      _(FinanceTracker::Transaction.count).must_equal 0
    end

    it 'rejects a destination wallet the caller does not own with 422' do
      bobs_wallet = FinanceTracker::Wallet.create(
        account_id: @bob.id, name: 'Bob Cash', method_type: 'cash', balance: 0
      )
      post_transfer(transfer_body(to_wallet_id: bobs_wallet.id))
      _(last_response.status).must_equal 422
      _(FinanceTracker::Transaction.count).must_equal 0
    end

    it 'rejects a non-positive amount with 422' do
      post_transfer(transfer_body(amount: '0'))
      _(last_response.status).must_equal 422
      _(FinanceTracker::Transaction.count).must_equal 0
    end

    it 'requires authentication' do
      post 'api/v1/transfers', transfer_body.to_json, @json
      _(last_response.status).must_equal 401
      _(FinanceTracker::Transaction.count).must_equal 0
    end
  end
end
