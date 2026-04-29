# frozen_string_literal: true

require_relative '../require_app'
require_app(['config'])
require 'sequel'

Sequel.extension :migration
Sequel::Migrator.run(FinanceTracker::Api.DB, 'app/db/migrations')

require 'rack/test'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/rg'
require 'yaml'
require 'json'

require_app(%w[config models controllers])

def app
  FinanceTracker::Api
end