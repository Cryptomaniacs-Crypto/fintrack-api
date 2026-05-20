# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'VerifyRegistration service' do
  before do
    wipe_database
    @env_backup = {}

    set_env('RESEND_API_URL', 'https://api.resend.com/emails')
    set_env('RESEND_API_KEY', 'test-key')
    set_env('RESEND_FROM_EMAIL', 'onboarding@resend.dev')
    set_env('RESEND_FROM_NAME', 'Fintrack-Demo')

    @registration = {
      email: 'newperson@example.com',
      username: 'newperson',
      verification_url: 'https://app.example.com/auth/register/some-token'
    }
  end

  after do
    @env_backup.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    WebMock.reset!
  end

  def set_env(key, value)
    @env_backup[key] = ENV[key]
    ENV[key] = value
  end

  it 'HAPPY: POSTs the Resend envelope and returns the registration' do
    stub = stub_request(:post, ENV.fetch('RESEND_API_URL'))
           .with(headers: { 'Authorization' => 'Bearer test-key' })
           .to_return(status: 200, body: { id: 'fake-email-id' }.to_json)

    result = FinanceTracker::VerifyRegistration.new(@registration).call

    _(result[:email]).must_equal @registration[:email]
    assert_requested(stub)
  end

  it 'SECURITY: request body uses Resend envelope with from/to/subject/html' do
    stub_request(:post, ENV.fetch('RESEND_API_URL')).to_return(status: 200)

    FinanceTracker::VerifyRegistration.new(@registration).call

    assert_requested(:post, ENV.fetch('RESEND_API_URL')) do |req|
      body = JSON.parse(req.body)
      body['from'].include?('onboarding@resend.dev') &&
        body['to'] == [@registration[:email]] &&
        body['subject'].include?('Verification') &&
        body['html'].include?(@registration[:verification_url])
    end
  end

  it 'SAD: raises InvalidRegistration when email already registered' do
    FinanceTracker::Account.create(username: 'existing', email: @registration[:email], password: 'password123')

    _ { FinanceTracker::VerifyRegistration.new(@registration).call }
      .must_raise FinanceTracker::VerifyRegistration::InvalidRegistration
  end

  it 'SAD: raises InvalidRegistration when username already taken' do
    FinanceTracker::Account.create(username: @registration[:username], email: 'other@example.com', password: 'password123')

    _ { FinanceTracker::VerifyRegistration.new(@registration).call }
      .must_raise FinanceTracker::VerifyRegistration::InvalidRegistration
  end

  it 'SAD: raises EmailProviderError on 4xx response from Resend' do
    stub_request(:post, ENV.fetch('RESEND_API_URL'))
      .to_return(status: 400, body: { message: 'bad' }.to_json)

    _ { FinanceTracker::VerifyRegistration.new(@registration).call }
      .must_raise FinanceTracker::VerifyRegistration::EmailProviderError
  end

  it 'SAD: raises EmailProviderError on 5xx response from Resend' do
    stub_request(:post, ENV.fetch('RESEND_API_URL')).to_return(status: 503, body: 'unavailable')

    _ { FinanceTracker::VerifyRegistration.new(@registration).call }
      .must_raise FinanceTracker::VerifyRegistration::EmailProviderError
  end
end
