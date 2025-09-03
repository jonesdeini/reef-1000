require 'http'

class FusionAuthenticator
  FUSION_PATH = 'https://apexfusion.com'.freeze

  def self.authenticate
    new.authenticate
  end

  def initialize
    @cookies = []
  end

  def authenticate
    csrf_token = get_csrf_token

    response = HTTP.timeout(30)
                 .follow
                 .cookies(cookies)
                 .headers("X-CSRF-Token" => csrf_token)
                 .post "#{FUSION_PATH}/login", form: login_payload

    response.cookies.cookies
  end

  private

  attr_reader :cookies

  def login_payload
    {
      username: Rails.application.config.x.apex.fusion_username,
      password: Rails.application.config.x.apex.fusion_password,
      remember_me: 'false'
    }
  end

  def get_csrf_token
    response = HTTP.timeout(30)
                 .follow
                 .get "#{FUSION_PATH}/login"
    @cookies = response.cookies.cookies
    extract_csrf_token response.body.to_s
  end

  def extract_csrf_token(html)
    match = html.match /name="csrf-token" content="([^"]+)"/
    match ? match[1] : nil
  end
end
