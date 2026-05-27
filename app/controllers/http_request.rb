# frozen_string_literal: true

require 'json'

module FinanceTracker
  # Small request wrapper for JSON bodies and bearer tokens.
  class HttpRequest
    def initialize(routing)
      @routing = routing
    end

    def body_data
      @body_data ||= begin
        raw = @routing.body&.read.to_s
        raw.empty? ? {} : JSON.parse(raw, symbolize_names: true)
      end
    end

    def auth_token
      auth_header = @routing.env['HTTP_AUTHORIZATION']
      return nil unless auth_header

      auth_header[/\ABearer\s+(.+)\z/i, 1]
    end

    def secure?
      raise 'Secure scheme not configured' unless Api.config.SECURE_SCHEME

      @routing.scheme.casecmp(Api.config.SECURE_SCHEME).zero?
    end
  end
end
