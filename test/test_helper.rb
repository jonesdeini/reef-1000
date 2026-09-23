# frozen_string_literal: true

if ENV['CI']
  require 'simplecov'
  SimpleCov.start 'rails' do
    minimum_coverage 100
  end
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'
require 'webmock/minitest'
require 'factory_bot_rails'

WebMock.disable_net_connect!(
  allow_localhost: true,
  net_http_connect_on_start: true
)

module ActiveSupport
  class TestCase

    include FactoryBot::Syntax::Methods

  end
end
