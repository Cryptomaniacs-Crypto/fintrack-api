# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
require 'date'
require 'yaml'
require_relative 'test_load_all'

TABLES_TO_WIPE = %i[accounts_roles accounts roles transactions wallets categories].freeze

def wipe_database
  TABLES_TO_WIPE.each do |table_name|
    FinanceTracker::Api.DB[table_name].delete if FinanceTracker::Api.DB.tables.include?(table_name)
  end
end

DATA = {} # rubocop:disable Style/MutableConstant
DATA[:wallets] = YAML.safe_load_file('db/seeds/wallet_seed.yml')
DATA[:categories] = YAML.safe_load_file('db/seeds/category_seed.yml')
DATA[:transactions] = YAML.safe_load_file(
  'db/seeds/transaction_seed.yml',
  permitted_classes: [Date],
  aliases: true
)