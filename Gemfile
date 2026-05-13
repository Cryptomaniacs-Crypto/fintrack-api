# frozen_string_literal: true

source 'https://rubygems.org'

ruby File.read('.ruby-version').strip if File.exist?('.ruby-version')

# Web API
gem 'base64'
gem 'json'
gem 'logger', '~> 1.0'
gem 'puma', '~>7.0'
gem 'roda', '~>3.0'

# Security
gem 'rbnacl', '~>7.0'

# Database
gem 'figaro'
gem 'rake'
gem 'sequel'

group :production do
  gem 'pg'
end

group :development, :test do
  gem 'rack-test'
  gem 'sqlite3'
end

group :test do
  gem 'minitest'
  gem 'minitest-rg'
end

group :development do
  gem 'bundler-audit'
  gem 'pry'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
end
