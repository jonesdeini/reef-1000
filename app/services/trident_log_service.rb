# frozen_string_literal: true

class TridentLogService < ApexClient
  MAX_DAYS = 7

  def self.log(days: MAX_DAYS)
    new.log days: days
  end

  def log(days: MAX_DAYS)
    get "#{base_path}/tlog?days=#{days}"
  end
end
