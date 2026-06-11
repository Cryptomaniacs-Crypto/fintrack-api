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

    # `auth` is the requester's AuthorizedAccount (their session token).
    # `requested_scope` is an optional scope string from the caller; the minted
    # token will carry that scope, capped to the caller's own scope so a caller
    # can never mint a token broader than what they already hold. Omitting it (or
    # passing an invalid / broader value) falls back to READ_ONLY.
    def self.call(auth:, username:, requested_scope: nil)
      target = GetAccountByUsername.call(username:)
      requester = requester_for(auth)
      # Anonymous callers get only the minimal public profile (username +
      # avatar) -- never email, system roles, or anything that enables
      # unauthenticated PII disclosure / email<->identity correlation.
      return { 'data' => target.public_summary } unless requester

      envelope = base_envelope(target)
      mint_scope = resolve_mint_scope(requested_scope, auth&.scope)
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

    # Resolves the scope to bake into the minted API-key token.
    # The requested scope must be well-formed AND a strict subset of the
    # caller's own scope — otherwise we fall back to READ_ONLY so a bad or
    # over-broad request can never escalate privilege.
    def self.resolve_mint_scope(requested, caller_scope)
      return AuthScope::READ_ONLY unless requested

      parsed = AuthScope.new(requested)
      return AuthScope::READ_ONLY unless parsed.valid? && parsed.subset_of?(caller_scope || AuthScope.new)

      requested
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
