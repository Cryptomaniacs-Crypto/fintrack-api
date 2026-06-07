# frozen_string_literal: true

require 'json'

require_relative 'get_account_by_username'
require_relative '../policies/account_policy'
require_relative '../models/authorized_account'
require_relative '../lib/auth_scope'

module FinanceTracker
  # Builds the account-detail envelope for GET /accounts/[username] and, for an
  # authenticated owner viewing their own account, mints a reduced-scope
  # (READ_ONLY by default) "API key" auth_token they can hand to a read-only
  # deputy or use from the command line.
  #
  # Anonymous callers still receive the public account envelope (no policies,
  # no token), preserving the API's existing unauthenticated read surface.
  class AuthorizeAccount
    # Raised when an authenticated requester may not view the target account.
    # The controller maps this to 404 so account existence is not leaked.
    class ForbiddenError < StandardError
      def message
        'You are not allowed to access that account'
      end
    end

    # `mint_scope` is the scope baked into the API-key token handed back to the
    # owner; `auth` is the requester's AuthorizedAccount (their session token).
    def self.call(auth:, username:, mint_scope: AuthScope::READ_ONLY)
      target = GetAccountByUsername.call(username:)
      requester = requester_for(auth)
      envelope = base_envelope(target)
      return envelope unless requester

      add_authorization!(envelope, target, requester, auth, mint_scope)
      envelope
    end

    # Enriches the envelope for an authenticated requester: policy summary for
    # anyone allowed to view, plus capabilities and a minted API-key token when
    # the requester is the account owner.
    def self.add_authorization!(envelope, target, requester, auth, mint_scope)
      policy = AccountPolicy.new(requester, target, auth_scope: auth&.scope || AuthScope.new)
      raise ForbiddenError unless policy.can_view?

      envelope['policies'] = policy.summary
      return unless requester.id == target.id

      envelope['capabilities'] = policy.capabilities
      envelope['account_api_token'] = AuthorizedAccount.new(envelope, mint_scope, account_id: target.id).token
    end

    def self.requester_for(auth)
      requester_id = auth&.account&.dig('attributes', 'id')
      requester_id && Account.first(id: requester_id)
    end

    def self.base_envelope(account)
      envelope = JSON.parse(account.to_json)
      envelope['included'] = {
        system_roles: account.system_roles.map { |role| { id: role.id, name: role.name } }
      }
      envelope
    end
  end
end
