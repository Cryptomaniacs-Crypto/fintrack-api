# frozen_string_literal: true

require 'date'
require 'yaml'

module FinanceTracker
  module DatabaseSeed
    DIR = File.dirname(__FILE__)
    ROLES_INFO = YAML.load_file(File.join(DIR, 'roles_seed.yml'))
    ACCOUNTS_INFO = YAML.load_file(File.join(DIR, 'accounts_seed.yml'))
    WALLETS_INFO = YAML.load_file(File.join(DIR, 'wallet_seed.yml'))
    CATEGORIES_INFO = YAML.load_file(File.join(DIR, 'category_seed.yml'))
    TRANSACTIONS_INFO = YAML.safe_load(
      File.read(File.join(DIR, 'transaction_seed.yml')),
      permitted_classes: [Date],
      aliases: true
    )
    ACCOUNTS_ROLES_INFO = YAML.load_file(File.join(DIR, 'accounts_roles_seed.yml'))

    def self.run
      puts 'Seeding roles, accounts, wallets, categories, transactions, and account roles'
      create_roles
      create_accounts
      create_wallets
      create_categories
      create_transactions
      create_accounts_roles
    end

    def self.create_roles
      ROLES_INFO.each do |role_info|
        FinanceTracker::Role.first(name: role_info['name']) || FinanceTracker::Role.create(role_info)
      end
    end

    def self.create_accounts
      ACCOUNTS_INFO.each do |account_info|
        next if FinanceTracker::Account.first(username: account_info['username'])

        FinanceTracker::Account.create(account_info)
      end
    end

    def self.create_wallets
      WALLETS_INFO.each do |wallet_info|
        FinanceTracker::Wallet.first(name: wallet_info['name']) || FinanceTracker::Wallet.create(wallet_info)
      end
    end

    def self.create_categories
      CATEGORIES_INFO.each do |category_info|
        FinanceTracker::Category.first(name: category_info['name']) || FinanceTracker::Category.create(category_info)
      end
    end

    def self.create_transactions
      TRANSACTIONS_INFO.each do |transaction_info|
        transaction_data = transaction_info.dup
        wallet = FinanceTracker::Wallet.first(name: transaction_data.delete('wallet_name'))
        category_name = transaction_data.delete('category_name')
        category = category_name && FinanceTracker::Category.first(name: category_name)

        next unless wallet

        lookup = {
          title: transaction_data['title'],
          transaction_date: transaction_data['transaction_date'],
          wallet_id: wallet.id
        }
        next if FinanceTracker::Transaction.first(lookup)

        FinanceTracker::Transaction.create(transaction_data.merge('wallet_id' => wallet.id, 'category_id' => category&.id))
      end
    end

    def self.create_accounts_roles
      ACCOUNTS_ROLES_INFO.each do |account_role_info|
        account = FinanceTracker::Account.first(username: account_role_info['username'])
        role = FinanceTracker::Role.first(name: account_role_info['role_name'])
        next unless account && role

        join = FinanceTracker::Account.db[:accounts_roles]
        next if join.where(account_id: account.id, role_id: role.id).first

        join.insert(account_id: account.id, role_id: role.id)
      end
    end
  end
end