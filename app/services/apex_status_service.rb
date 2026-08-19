# frozen_string_literal: true

class ApexStatusService < ApexClient
  def self.status
    new.status
  end

  def status
    get base_path
  end
end
