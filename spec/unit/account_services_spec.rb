# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account Services' do
  before do
    wipe_database
  end

  let(:account_data) do
    {
      'username' => 'service.user',
      'email' => 'service.user@example.com',
      'password' => 'service-password',
      'avatar' => 'service.png'
    }
  end

  it 'HAPPY: CreateAccount should persist account data' do
    account = FinanceTracker::CreateAccount.call(account_data:)

    _(account.username).must_equal account_data['username']
    _(account.password?(account_data['password'])).must_equal true
  end

  it 'HAPPY: GetAccountByUsername should return the requested account' do
    created = FinanceTracker::CreateAccount.call(account_data:)
    found = FinanceTracker::GetAccountByUsername.call(username: created.username)

    _(found.id).must_equal created.id
  end

  it 'HAPPY: FindAccountByEmail should locate account from plaintext email' do
    created = FinanceTracker::CreateAccount.call(account_data:)
    found = FinanceTracker::FindAccountByEmail.call(email: account_data['email'])

    _(found.id).must_equal created.id
  end

  it 'HAPPY: AssignRoleToAccount should link role and account through join table' do
    account = FinanceTracker::CreateAccount.call(account_data:)
    FinanceTracker::Role.create(name: 'member')

    FinanceTracker::AssignRoleToAccount.call(username: account.username, role_name: 'member')

    role_names = account.refresh.system_roles.map(&:name)
    _(role_names).must_equal ['member']
  end

  it 'HAPPY: ListAccountRoles should return assigned roles' do
    account = FinanceTracker::CreateAccount.call(account_data:)
    FinanceTracker::Role.create(name: 'admin')
    FinanceTracker::Role.create(name: 'member')
    FinanceTracker::AssignRoleToAccount.call(username: account.username, role_name: 'admin')
    FinanceTracker::AssignRoleToAccount.call(username: account.username, role_name: 'member')

    roles = FinanceTracker::ListAccountRoles.call(username: account.username)
    _(roles.map(&:name).sort).must_equal %w[admin member]
  end
end
