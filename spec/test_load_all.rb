# frozen_string_literal: true

require 'rack/test'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/rg'
require 'yaml'
require 'json'

require_relative '../app/controllers/app'
require_relative '../app/models/transaction'
require_relative '../app/models/wallet'
require_relative '../app/models/category'
require_relative '../app/models/password'
require_relative '../app/models/account'
require_relative '../app/models/role'

def app
  FinanceTracker::Api
end