# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require_relative 'test_load_all'

def wipe_database
  FinanceTracker::Transaction.dataset.delete  # child (has account_id, category_id)
  FinanceTracker::Account.dataset.delete      # parent
  FinanceTracker::Category.dataset.delete     # parent
end

DATA = {}
DATA[:transactions] = YAML.safe_load_file('db/seeds/transaction_seed.yml')
DATA[:accounts] = YAML.safe_load_file('db/seeds/account_seed.yml')
DATA[:categories] = YAML.safe_load_file('db/seeds/category_seed.yml')