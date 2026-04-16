# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require_relative 'test_load_all'

def wipe_database
  FinanceTracker::Account.dataset.delete
  FinanceTracker::Category.dataset.delete
  FinanceTracker::Transaction.dataset.delete
end

DATA = {}
DATA[:transactions] = YAML.safe_load_file('db/seeds/transaction_seed.yml')
DATA[:accounts] = YAML.safe_load_file('db/seeds/account_seed.yml')
DATA[:categories] = YAML.safe_load_file('db/seeds/category_seed.yml')