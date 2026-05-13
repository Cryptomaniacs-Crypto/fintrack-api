# frozen_string_literal: true

require 'rake/testtask'
require './require_app'
require_relative './app/lib/secure_db'

task default: :spec

namespace :newkey do
  desc 'Create sample cryptographic key for database encryption'
  task :db do
    puts "SECURE_DB_KEY: #{FinanceTracker::SecureDB.generate_key}"
  end

  desc 'Create sample cryptographic key for HMAC lookup hashing'
  task :hash do
    puts "SECURE_HASH_KEY: #{FinanceTracker::SecureDB.generate_key}"
  end
end

desc 'Tests API specs only'
task :api_spec do
  sh 'ruby spec/integration/api_spec.rb'
end

desc 'Test all the specs'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.warning = false
end

desc 'Runs rubocop on tested code'
task style: %i[spec audit] do
  sh 'rubocop .'
end

desc 'Update vulnerabilities list and audit gems'
task :audit do
  sh 'bundle audit check --update'
end

desc 'Checks for release'
task release_check: %i[spec style audit] do
  puts "\nReady for release!"
end

task :print_env do # rubocop:disable Rake/Desc
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run application console (pry)'
task console: :print_env do
  sh 'pry -r ./spec/test_load_all'
end

namespace :db do
  task :load do # rubocop:disable Rake/Desc
    require_app(['config'])
    require 'sequel'

    Sequel.extension :migration
    @app = FinanceTracker::Api
  end

  task :load_models do # rubocop:disable Rake/Desc
    require_app(%w[config models])
  end

  desc 'Run migrations'
  task migrate: %i[load print_env] do
    puts 'Migrating database to latest'
    Sequel::Migrator.run(@app.DB, 'app/db/migrations')
  end

  desc 'Destroy data in database; maintain tables'
  task reset_seeds: :load_models do # rubocop:disable Rake/Desc
    FinanceTracker::Api.DB[:accounts_roles].delete if FinanceTracker::Api.DB.tables.include?(:accounts_roles)
    FinanceTracker::Transaction.dataset.delete if FinanceTracker::Api.DB.tables.include?(:transactions)
    FinanceTracker::Wallet.dataset.delete if FinanceTracker::Api.DB.tables.include?(:wallets)
    FinanceTracker::Category.dataset.delete if FinanceTracker::Api.DB.tables.include?(:categories)
    FinanceTracker::Account.dataset.delete if FinanceTracker::Api.DB.tables.include?(:accounts)
    FinanceTracker::Role.dataset.delete if FinanceTracker::Api.DB.tables.include?(:roles)
  end

  desc 'Seed the development database'
  task seed: %i[load migrate load_models print_env] do
    require_relative './db/seeds/20260429_create_all'

    FinanceTracker::DatabaseSeed.run
  end

  desc 'Delete dev or test database file'
  task drop: :load do
    if @app.environment == :production
      puts 'Cannot wipe production database!'
      return
    end

    db_filename = "app/db/#{FinanceTracker::Api.environment}.db"
    FileUtils.rm(db_filename)
    puts "Deleted #{db_filename}"
  end

  desc 'Bootstrap an admin: ensure roles, create-or-find USERNAME, grant admin+creator'
  task bootstrap_admin: :load_models do
    require 'io/console'

    username = ENV.fetch('USERNAME', nil).to_s.strip
    email = ENV.fetch('EMAIL', nil).to_s.strip
    abort 'USERNAME=<username> required' if username.empty?

    # 1. Ensure the static roles reference table is populated.
    role_names = %w[admin creator member]
    role_names.each { |name| FinanceTracker::Role.find_or_create(name:) }
    puts "Roles ensured: #{role_names.join(', ')}"

    # 2. Create-or-find the account.
    account = FinanceTracker::Account.first(username:)
    if account.nil?
      abort 'EMAIL=<email> required when creating a new account' if email.empty?
      password =
        if $stdin.tty?
          print 'Password (input hidden): '
          pw = $stdin.noecho(&:gets).to_s.chomp
          puts ''
          pw
        else
          warn '(no TTY -- reading password from stdin without echo masking)'
          $stdin.gets.to_s.chomp
        end
      abort 'Password must be at least 8 characters' if password.length < 8

      account = FinanceTracker::Account.create(username:, email:, password:)
      puts "+ Created account #{username} (id=#{account.id})"
    else
      puts "- Account #{username} already exists (id=#{account.id})"
    end

    # 3. Grant admin + creator (idempotent).
    %w[admin creator].each do |role_name|
      if account.system_roles_dataset.where(name: role_name).any?
        puts "  - already has '#{role_name}'"
      else
        account.add_system_role(FinanceTracker::Role.first(name: role_name))
        puts "  + granted '#{role_name}'"
      end
    end
  end
end

desc 'Delete all data and reseed'
task reseed: %i[db:reset_seeds db:seed]
