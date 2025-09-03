class ApexStatusService

  def self.get_status
    new.get_status
  end

  def initialize
    @cookies = FusionAuthenticator.authenticate
  end

  def get_status
    HTTP.timeout(30)
      .follow
      .cookies(cookies)
      .get(status_path)
      .body
      .to_s
  end

  private

  attr_reader :cookies

  def status_path
    "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}"
  end

end
