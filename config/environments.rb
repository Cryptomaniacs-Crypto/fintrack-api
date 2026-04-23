# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'sequel'
require_relative '../app/lib/secure_db'

module FinanceTracker
  class Api < Roda
    plugin :environments

    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load

    def self.config = Figaro.env

    SecureDB.setup(config.SECURE_DB_KEY)

    db_url = ENV.delete('DATABASE_URL')
    DB = Sequel.connect("#{db_url}?encoding=utf8")
    def self.DB = DB

    configure :development, :production do
      plugin :common_logger, $stderr
    end

    configure :development, :test do
      require 'pry'
    end
  end
end