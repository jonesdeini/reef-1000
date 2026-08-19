# frozen_string_literal: true

require 'http'

class ApexClient
  def initialize
    @cookies = FusionAuthenticator.authenticate
  end

  private

  attr_reader :cookies

  def get(path)
    HTTP.timeout(30)
        .follow
        .cookies(cookies)
        .get(path)
        .body
        .to_s
  end

  def base_path
    "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}"
  end
end
