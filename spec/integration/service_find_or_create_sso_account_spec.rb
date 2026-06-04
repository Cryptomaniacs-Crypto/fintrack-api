# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test FindOrCreateSsoAccount service' do
  before do
    wipe_database
    FinanceTracker::Role.find_or_create(name: 'member')
  end

  def google_claims(overrides = {})
    {
      provider: 'google',
      external_id: 'google-sub-123',
      email: 'newuser@example.com',
      email_verified: true,
      name: 'New User',
      avatar: 'https://example.com/photo.jpg'
    }.merge(overrides)
  end

  it 'HAPPY: creates a member account and identity for a first-time SSO login' do
    account = FinanceTracker::FindOrCreateSsoAccount.call(**google_claims)

    _(account).must_be_kind_of FinanceTracker::Account
    _(account.system_roles.map(&:name)).must_include 'member'
    _(account.email).must_equal 'newuser@example.com'
    _(account.avatar).must_equal 'https://example.com/photo.jpg'

    identity = FinanceTracker::SsoIdentity.first(provider: 'google', external_id: 'google-sub-123')
    _(identity).wont_be_nil
    _(identity.account_id).must_equal account.id
  end

  it 'HAPPY: a repeat login with the same identity returns the same account (idempotent)' do
    first  = FinanceTracker::FindOrCreateSsoAccount.call(**google_claims)
    second = FinanceTracker::FindOrCreateSsoAccount.call(**google_claims)

    _(second.id).must_equal first.id
    _(FinanceTracker::SsoIdentity.where(provider: 'google', external_id: 'google-sub-123').count).must_equal 1
    _(FinanceTracker::Account.count).must_equal 1
  end

  it 'LINK: links a verified-email match to an existing password account' do
    existing = FinanceTracker::Account.new(
      username: 'existing_user', email: 'newuser@example.com', password: 'PangolinReef42!'
    )
    existing.save_changes

    account = FinanceTracker::FindOrCreateSsoAccount.call(**google_claims)

    _(account.id).must_equal existing.id
    _(FinanceTracker::Account.count).must_equal 1
    _(FinanceTracker::SsoIdentity.first(provider: 'google', external_id: 'google-sub-123').account_id)
      .must_equal existing.id
  end

  it 'SECURITY: unverified email matching an existing account raises EmailConflictError' do
    FinanceTracker::Account.new(
      username: 'existing_user', email: 'newuser@example.com', password: 'PangolinReef42!'
    ).save_changes

    _ { FinanceTracker::FindOrCreateSsoAccount.call(**google_claims(email_verified: false)) }
      .must_raise FinanceTracker::FindOrCreateSsoAccount::EmailConflictError

    _(FinanceTracker::Account.count).must_equal 1
    _(FinanceTracker::SsoIdentity.count).must_equal 0
  end

  it 'HAPPY: creates a fresh account for an unverified email that has no collision' do
    account = FinanceTracker::FindOrCreateSsoAccount.call(
      **google_claims(email_verified: false, email: 'fresh@example.com', external_id: 'sub-x')
    )

    _(account).must_be_kind_of FinanceTracker::Account
    _(account.email).must_equal 'fresh@example.com'
    _(FinanceTracker::Account.count).must_equal 1
  end

  it 'HAPPY: derives username from the email local-part, suffixing @provider on collision' do
    FinanceTracker::Account.new(
      username: 'newuser', email: 'someone@else.com', password: 'PangolinReef42!'
    ).save_changes

    account = FinanceTracker::FindOrCreateSsoAccount.call(**google_claims)

    _(account.username).must_equal 'newuser@google'
  end
end
