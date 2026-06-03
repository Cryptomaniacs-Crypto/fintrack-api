# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Policies interpret auth scope' do
  before do
    wipe_database
  end

  let(:account) do
    FinanceTracker::CreateAccount.call(
      account_data: { 'username' => 'owner', 'email' => 'owner@example.com',
                      'password' => 'owner-pass', 'avatar' => 'o.png' }
    )
  end
  let(:wallet) { FinanceTracker::Wallet.create(DATA[:wallets][0].merge(account_id: account.id)) }
  let(:read_only) { FinanceTracker::AuthScope.new(FinanceTracker::AuthScope::READ_ONLY) }
  let(:full) { FinanceTracker::AuthScope.new }

  it 'HAPPY: READ_ONLY lets the owner view but not edit their wallet' do
    policy = FinanceTracker::WalletPolicy.new(account, wallet, auth_scope: read_only)
    _(policy.can_view?).must_equal true
    _(policy.can_edit?).must_equal false
    _(policy.can_delete?).must_equal false
  end

  it 'HAPPY: FULL lets the owner view and edit their wallet' do
    policy = FinanceTracker::WalletPolicy.new(account, wallet, auth_scope: full)
    _(policy.can_view?).must_equal true
    _(policy.can_edit?).must_equal true
  end

  it 'SECURITY: READ_ONLY blocks account write capabilities even for the owner' do
    policy = FinanceTracker::AccountPolicy.new(account, account, auth_scope: read_only)
    _(policy.can_view?).must_equal true
    _(policy.can_edit?).must_equal false
    _(policy.can_create_wallet?).must_equal false
    _(policy.can_create_transaction?).must_equal false
  end
end
