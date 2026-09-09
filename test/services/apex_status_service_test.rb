# frozen_string_literal: true

require 'test_helper'

class ApexStatusServiceTest < ActiveSupport::TestCase
  setup do
    @cookies = [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')]
    @tank_status_json = { 'status' => { 'inputs' => [{ 'type' => 'alk', 'value' => 8.5 }] } }.to_json
    @status_url = "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}"
  end

  test 'authenticates first and returns the tank status JSON on success' do
    auth_calls = 0

    FusionAuthenticator.stub :authenticate, lambda {
      auth_calls += 1
      @cookies
    } do
      stub_request(:get, @status_url).to_return status: 200, body: @tank_status_json

      result = ApexStatusService.status

      assert_equal 1, auth_calls
      assert_equal @tank_status_json, result
    end
  end

  test 'returns the raw body rather than raising on an API error' do
    FusionAuthenticator.stub :authenticate, @cookies do
      stub_request(:get, @status_url).to_return status: 500, body: 'Server Error'

      assert_equal 'Server Error', ApexStatusService.status
    end
  end
end
