# frozen_string_literal: true

class ActionExecutor

  def self.call
    Decision.where(executed_at: nil).find_each do |decision|
      Rails.logger.info { "ActionExecutor: #{decision.action}" }
      decision.update! executed_at: Time.current
    end
  end

end
