# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Account Model' do
  before do
    wipe_database
  end

  let(:account_data) do
    { username: 'jane.doe', email: 'jane@example.com',
      password: 's3cret-pa55', avatar: 'jane.png' }
  end

  it 'HAPPY: should create and retrieve an account' do
    new_account = FinanceTracker::Account.create(account_data)

    fetched = FinanceTracker::Account.find(id: new_account.id)
    _(fetched.username).must_equal account_data[:username]
    _(fetched.email).must_equal account_data[:email]
    _(fetched.avatar).must_equal account_data[:avatar]
  end

  it 'SECURITY: should not use deterministic integers as ID' do
    new_account = FinanceTracker::Account.create(account_data)

    _(new_account.id.is_a?(Numeric)).must_equal false
  end

  it 'SECURITY: should store email encrypted, not plaintext' do
    new_account = FinanceTracker::Account.create(account_data)
    stored = FinanceTracker::Api.DB[:accounts].first(id: new_account.id)

    _(stored[:email_secure]).wont_equal account_data[:email]
    _(stored[:email_hash]).wont_equal account_data[:email]
  end

  it 'SECURITY: should produce a stable email_hash for lookup' do
    FinanceTracker::Account.create(account_data)
    stored = FinanceTracker::Api.DB[:accounts].first(username: account_data[:username])

    expected_hash = FinanceTracker::SecureDB.hash(account_data[:email])
    _(stored[:email_hash]).must_equal expected_hash
  end

  it 'SECURITY: should never store the password in plaintext' do
    new_account = FinanceTracker::Account.create(account_data)
    stored = FinanceTracker::Api.DB[:accounts].first(id: new_account.id)

    _(stored[:password_digest]).wont_be_nil
    _(stored[:password_digest]).wont_match(/#{account_data[:password]}/)
  end

  it 'SECURITY: should verify a correct password' do
    new_account = FinanceTracker::Account.create(account_data)

    _(new_account.password?(account_data[:password])).must_equal true
  end

  it 'SECURITY: should reject an incorrect password' do
    new_account = FinanceTracker::Account.create(account_data)

    _(new_account.password?('wrong-password')).must_equal false
  end

  it 'SECURITY: should not expose password_digest in JSON output' do
    new_account = FinanceTracker::Account.create(account_data)
    json = JSON.parse(new_account.to_json)

    _(json['data']['attributes']).wont_include 'password'
    _(json['data']['attributes']).wont_include 'password_digest'
    _(json['data']['attributes']).wont_include 'email_secure'
    _(json['data']['attributes']).wont_include 'email_hash'
  end

  it 'HAPPY: can attach system roles via many-to-many' do
    admin = FinanceTracker::Role.create(name: 'admin')
    member = FinanceTracker::Role.create(name: 'member')
    account = FinanceTracker::Account.create(account_data)

    account.add_system_role(admin)
    account.add_system_role(member)

    role_names = account.system_roles.map(&:name).sort
    _(role_names).must_equal %w[admin member]
  end
end
