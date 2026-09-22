# frozen_string_literal: true

require 'test_helper'

class IntervalLogServiceTest < ActiveSupport::TestCase

  setup do
    @cookies = [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')]
    @log_json = [{ 'date' => '2026-08-18T13:20:00.000Z',
                   'inputs' => [{ 'did' => 'base_pH', 'value' => 7.87 }] }].to_json
    @log_url = "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}/ilog"
  end

  test 'authenticates first and returns the interval log JSON for the default window' do
    stub_request(:get, "#{@log_url}?days=7").to_return status: 200, body: @log_json
    authenticate_calls = []

    FusionAuthenticator.stub(:authenticate, lambda {
      authenticate_calls << true
      @cookies
    }) do
      assert_equal @log_json, IntervalLogService.log
    end

    assert_equal 1, authenticate_calls.size
  end

  test 'requests a custom window when days is given' do
    FusionAuthenticator.stub :authenticate, @cookies do
      stub_request(:get, "#{@log_url}?days=1").to_return status: 200, body: @log_json

      assert_equal @log_json, IntervalLogService.log(days: 1)
    end
  end

end
