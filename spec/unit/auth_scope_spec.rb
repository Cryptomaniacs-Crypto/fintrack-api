# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AuthScope' do
  let(:read_only) { FinanceTracker::AuthScope::READ_ONLY }
  let(:full) { FinanceTracker::AuthScope::FULL }

  def scope(grants = nil)
    grants ? FinanceTracker::AuthScope.new(grants) : FinanceTracker::AuthScope.new
  end

  it 'HAPPY: FULL (default) allows read and write on any resource' do
    _(scope.can_read?('wallets')).must_equal true
    _(scope.can_write?('wallets')).must_equal true
    _(scope.can_write?('anything-at-all')).must_equal true
  end

  it 'HAPPY: READ_ONLY allows read but never write' do
    _(scope(read_only).can_read?('wallets')).must_equal true
    _(scope(read_only).can_read?('transactions')).must_equal true
    _(scope(read_only).can_write?('wallets')).must_equal false
  end

  it 'HAPPY: write implies read for the same resource' do
    _(scope('wallets:write').can_read?('wallets')).must_equal true
    _(scope('wallets:write').can_write?('wallets')).must_equal true
  end

  it 'SECURITY: grants are resource-specific' do
    _(scope('wallets:read').can_read?('wallets')).must_equal true
    _(scope('wallets:read').can_read?('transactions')).must_equal false
    _(scope('wallets:read').can_write?('wallets')).must_equal false
  end

  it 'HAPPY: supports multiple space-separated grants' do
    multi = scope('wallets:read transactions:write')
    _(multi.can_read?('wallets')).must_equal true
    _(multi.can_write?('wallets')).must_equal false
    _(multi.can_write?('transactions')).must_equal true
    _(multi.can_read?('transactions')).must_equal true
  end

  it 'HAPPY: round-trips to its string form' do
    _(scope('wallets:read').to_s).must_equal 'wallets:read'
    _(scope.to_s).must_equal full
  end
end
