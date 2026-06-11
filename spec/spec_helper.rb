# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
require 'date'
require 'yaml'
require_relative 'test_load_all'

TABLES_TO_WIPE = %i[
  bill_split_item_shares bill_split_items bill_split_participants bill_splits
  friendships sso_identities accounts_roles accounts roles transactions wallets categories
].freeze

def wipe_database
  TABLES_TO_WIPE.each do |table_name|
    FinanceTracker::Api.DB[table_name].delete if FinanceTracker::Api.DB.tables.include?(table_name)
  end
end

# Mint a real encrypted auth token for an account (FULL scope by default).
# Pass a scope string (e.g. FinanceTracker::AuthScope::READ_ONLY) for a
# reduced-scope key.
def auth_token_for(account, scope: FinanceTracker::AuthScope.new)
  scope = FinanceTracker::AuthScope.new(scope) if scope.is_a?(String)
  payload = {
    'type' => 'account',
    'attributes' => { 'id' => account.id, 'username' => account.username }
  }
  FinanceTracker::AuthToken.new(payload, scope:).to_s
end

# Rack::Test header hash carrying a bearer token for the given account.
def auth_header_for(account, scope: FinanceTracker::AuthScope.new)
  { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token_for(account, scope:)}" }
end

# Wrap a request body the way the Web App does: sign it so the API's
# signature gate on /auth/* accepts it. The test env holds the signing half,
# so specs can forge a valid client signature.
def signed_body(body)
  FinanceTracker::SignedRequest.sign(body).to_json
end

DATA = {} # rubocop:disable Style/MutableConstant
DATA[:wallets] = YAML.safe_load_file('db/seeds/wallet_seed.yml')
DATA[:categories] = YAML.safe_load_file('db/seeds/category_seed.yml')
DATA[:transactions] = YAML.safe_load_file(
  'db/seeds/transaction_seed.yml',
  permitted_classes: [Date],
  aliases: true
)

# SSO test harness: a self-signed RSA key stands in for Google's signing key.
# Stubs Google's JWKS endpoint so SSO specs need no real credentials or network.
require 'openssl'
require 'jwt'

module SsoTestKeys
  KID = 'fintrack-test-key'

  module_function

  def signing_key
    @signing_key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def jwks
    { keys: [JWT::JWK.new(signing_key, { kid: KID }).export] }
  end

  def default_claims
    {
      'iss' => 'https://accounts.google.com',
      'aud' => ENV.fetch('GOOGLE_CLIENT_ID'),
      'sub' => '112345678901234567890',
      'email' => 'sso-user@example.com',
      'email_verified' => true,
      'name' => 'SSO User',
      'picture' => 'https://lh3.googleusercontent.com/a/sso-user',
      'exp' => Time.now.to_i + 3600
    }
  end

  # Mint a signed id_token. Pass overrides hash to patch claims (sad paths),
  # or a different key as the second arg to exercise bad-signature rejection.
  def mint_id_token(overrides = {}, key = signing_key)
    JWT.encode(default_claims.merge(overrides), key, 'RS256', { kid: KID })
  end
end