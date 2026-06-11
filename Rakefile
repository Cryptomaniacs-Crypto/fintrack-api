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

  desc 'Create sample cryptographic key for auth token encryption'
  task :token do
    require_relative './app/lib/auth_token'
    puts "TOKEN_KEY: #{FinanceTracker::AuthToken.generate_key}"
  end

  desc 'Create sign/verify keypair for signed client requests'
  task :signing do
    require_relative './app/lib/signed_request'
    keypair = FinanceTracker::SignedRequest.generate_keypair
    puts "SIGNING_KEY (app, private): #{keypair[:signing_key]}"
    puts "VERIFY_KEY  (api, public):  #{keypair[:verify_key]}"
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
    Sequel::Migrator.run(@app.DB, 'db/migrations')
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

  desc 'Bootstrap an admin: ensure roles, create-or-find USERNAME, grant admin+member'
  task bootstrap_admin: :load_models do
    require 'io/console'

    username = ENV.fetch('USERNAME', nil).to_s.strip
    email = ENV.fetch('EMAIL', nil).to_s.strip
    abort 'USERNAME=<username> required' if username.empty?

    # 1. Ensure the static roles reference table is populated.
    role_names = %w[admin member]
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

    # 3. Grant admin + member (idempotent).
    %w[admin member].each do |role_name|
      if account.system_roles_dataset.where(name: role_name).any?
        puts "  - already has '#{role_name}'"
      else
        account.add_system_role(FinanceTracker::Role.first(name: role_name))
        puts "  + granted '#{role_name}'"
      end
    end
  end

  desc 'Erase financial data (transactions, wallets, bill splits) but KEEP ' \
       'accounts, roles, SSO identities, and default categories'
  task wipe_data: :load_models do
    db = FinanceTracker::Api.DB
    # Child-first deletion order so foreign keys never block a delete.
    %i[
      bill_split_item_shares bill_split_items bill_split_participants
      bill_splits split_agreements transactions wallets
    ].each do |table|
      next unless db.tables.include?(table)

      puts "#{table}: #{db[table].delete} rows deleted"
    end

    if db.tables.include?(:categories)
      removed = db[:categories].exclude(is_default: true).delete
      puts "categories (non-default): #{removed} rows deleted"
    end

    puts "--- kept ---"
    puts "accounts:           #{db[:accounts].count}"
    puts "roles:              #{db[:roles].count}" if db.tables.include?(:roles)
    puts "sso_identities:     #{db[:sso_identities].count}" if db.tables.include?(:sso_identities)
    puts "default categories: #{db[:categories].where(is_default: true).count}"
  end

  desc 'Seed realistic demo data (wallets, categories, 6 months of transactions) ' \
       'for USERNAME=<username>. Safe to re-run; rebuilds the demo wallets each time.'
  task seed_demo: :load_models do
    require 'date'

    username = ENV.fetch('USERNAME', '').strip
    abort 'USERNAME=<username> required' if username.empty?
    account = FinanceTracker::Account.first(username:)
    abort "No account found for username '#{username}'" unless account

    rng   = Random.new(20260611)
    today = Date.today

    # ── Categories (global/shared) ──────────────────────────────────────
    category_defs = {
      'Salary'        => 'Income from work',
      'Groceries'     => 'Food and household',
      'Dining'        => 'Restaurants and cafes',
      'Transport'     => 'Commute and travel',
      'Shopping'      => 'Retail and online',
      'Entertainment' => 'Fun and leisure',
      'Bills'         => 'Utilities and subscriptions',
      'Health'        => 'Medical and fitness'
    }
    cat = category_defs.each_with_object({}) do |(name, desc), acc|
      acc[name] = FinanceTracker::Category.first(name:) ||
                  FinanceTracker::Category.create(name:, description: desc)
    end

    # ── Wallets (owned by the account) — rebuilt fresh each run ──────────
    wallet_defs = [['Cash', 'cash', 150], ['Bank Account', 'bank_account', 2800], ['E-Wallet', 'e_wallet', 320]]
    wallets = wallet_defs.each_with_object({}) do |(name, type, bal), acc|
      w = FinanceTracker::Wallet.first(name:, account_id: account.id)
      unless w
        w = FinanceTracker::Wallet.new(account_id: account.id, name:, method_type: type)
        w.balance = bal.to_s
        w.save_changes
      end
      acc[name] = w
    end
    wallet_ids = wallets.values.map(&:id)

    # Clear any prior demo transactions in these (demo-only) wallets.
    removed = FinanceTracker::Transaction.where(wallet_id: wallet_ids).delete
    puts "Cleared #{removed} existing transaction(s) in demo wallets"

    mk = lambda do |wallet, category, title, amount, date, note = '[demo]'|
      FinanceTracker::Transaction.create(
        'title' => title, 'amount' => format('%.2f', amount),
        'transaction_date' => date, 'note' => note,
        'wallet_id' => wallet.id, 'category_id' => category&.id
      )
    end

    expense_templates = {
      'Groceries'     => [['Supermarket run', 25, 80], ['Weekly groceries', 40, 120]],
      'Dining'        => [['Lunch out', 8, 25], ['Dinner with friends', 22, 60], ['Coffee', 3, 7]],
      'Transport'     => [['Fuel', 30, 70], ['Bus pass', 10, 30], ['Taxi ride', 8, 25]],
      'Shopping'      => [['New clothes', 25, 120], ['Online order', 15, 90]],
      'Entertainment' => [['Movie night', 10, 30], ['Concert', 40, 100], ['Streaming', 9, 16]],
      'Bills'         => [['Electricity', 30, 80], ['Internet', 25, 45], ['Phone plan', 15, 35]],
      'Health'        => [['Pharmacy', 8, 40], ['Gym membership', 20, 50]]
    }
    expense_cats = expense_templates.keys
    pool = wallets.values
    created = 0

    6.downto(0) do |m|
      month = today << m

      # Monthly salary on the 1st (skip future dates).
      salary_date = Date.new(month.year, month.month, 1)
      if salary_date <= today
        mk.call(wallets['Bank Account'], cat['Salary'], 'Monthly salary', 2900 + rng.rand(400), salary_date)
        created += 1
      end

      (8 + rng.rand(6)).times do
        cat_name = expense_cats.sample(random: rng)
        title, lo, hi = expense_templates[cat_name].sample(random: rng)
        day  = 1 + rng.rand(28)
        date = Date.new(month.year, month.month, day)
        next if date > today

        amount = -(lo + rng.rand(hi - lo + 1))
        mk.call(pool.sample(random: rng), cat[cat_name], title, amount, date)
        created += 1
      end

      # One internal transfer per month (Bank → Cash), shown as two net-zero legs.
      t_date = Date.new(month.year, month.month, [15, today.day].min)
      if t_date <= today
        mk.call(wallets['Bank Account'], nil, 'Transfer → Cash', -100, t_date, 'Transfer [demo]')
        mk.call(wallets['Cash'],         nil, 'Transfer ← Bank Account', 100, t_date, 'Transfer [demo]')
        created += 2
      end
    end

    puts "Demo data ready for @#{username}: #{wallets.size} wallets, #{cat.size} categories, #{created} transactions"
  end
end

desc 'Delete all data and reseed'
task reseed: %i[db:reset_seeds db:seed]

namespace :bill_splits do
  desc 'Email payment reminders to participants who have not paid in 3+ days'
  task remind: :print_env do
    require_app(%w[config models services])
    puts 'Sending bill split reminders...'
    FinanceTracker::RemindBillSplit.call
    puts 'Done.'
  end
end
