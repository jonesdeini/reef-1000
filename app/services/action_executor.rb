# frozen_string_literal: true

class ActionExecutor

  def self.call
    Decision.where(executed_at: nil, undecidable_reason: nil).find_each do |decision|
      Rails.logger.info { "ActionExecutor: #{decision.actions}" }
      decision.update! executed_at: Time.current
    end
  end

end
