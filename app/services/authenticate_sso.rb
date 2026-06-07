# frozen_string_literal: true

require 'json'
require_relative '../lib/auth_scope'

module FinanceTracker
  # Verify a Google-signed id_token, resolve it to an account, and issue a
  # FULL-scope auth token. The API trusts the *cryptographic* signature on the
  # id_token (verified against Google's JWKS) -- it never sees the user's Google
  # password and makes no userinfo callback.
  class AuthenticateSso
    def self.call(id_token)
      claims = GoogleIdToken.verify(id_token)
      account = FindOrCreateSsoAccount.call(**GoogleAccount.new(claims).to_h)

      roles = account.system_roles.map { |role| { id: role.id, name: role.name } }
      envelope = JSON.parse(account.to_json)
      envelope['included'] = { system_roles: roles }
      policy = ::FinanceTracker::AccountPolicy.new(account)
      envelope['policies'] = policy.summary
      envelope['capabilities'] = policy.capabilities
      envelope['auth_token'] = AuthorizedAccount.new(envelope, AuthScope.new, account_id: account.id).token
      envelope['account_api_token'] = AuthorizedAccount.new(envelope, AuthScope::READ_ONLY, account_id: account.id).token
      envelope
    end
  end
end
