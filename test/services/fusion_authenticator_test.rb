# frozen_string_literal: true

require 'test_helper'

class FusionAuthenticatorTest < ActiveSupport::TestCase
  setup do
    stub_request(:get, 'https://apexfusion.com/login').to_return(
      status: 200,
      body: '<meta name="csrf-token" content="test-csrf-token">',
      headers: { 'Set-Cookie' => 'connect.sid=initial-session' }
    )
  end

  test 'returns cookies from both the login page and the authenticated session when login succeeds' do
    stub_request(:post, 'https://apexfusion.com/login')
      .with(
        headers: {
          'X-CSRF-Token' => 'test-csrf-token',
          'Cookie' => 'connect.sid=initial-session'
        },
        body: {
          username: Rails.application.config.x.apex.fusion_username,
          password: Rails.application.config.x.apex.fusion_password,
          remember_me: 'false'
        }
      )
      .to_return(status: 200, headers: { 'Set-Cookie' => 'connect.sid=authenticated-session' })

    cookies = FusionAuthenticator.authenticate

    assert_equal %w[connect.sid connect.sid], cookies.map(&:name)
    assert_equal %w[initial-session authenticated-session], cookies.map(&:value)
  end

  test 'returns only the cookie from the login page when login fails' do
    stub_request(:post, 'https://apexfusion.com/login').to_return status: 401

    cookies = FusionAuthenticator.authenticate

    assert_equal ['connect.sid'], cookies.map(&:name)
    assert_equal ['initial-session'], cookies.map(&:value)
  end
end
