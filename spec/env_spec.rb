# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Secret credentials not exposed' do
  it 'HAPPY: should not find database url in environment' do
    _(FinanceTracker::Api.config.DATABASE_URL).must_be_nil
  end
end