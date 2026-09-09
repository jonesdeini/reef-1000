# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'
require 'webmock/minitest'

WebMock.disable_net_connect!(
  allow_localhost: true,
  net_http_connect_on_start: true
)
