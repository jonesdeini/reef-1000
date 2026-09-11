# frozen_string_literal: true

class AlkWatchdogJob < ApplicationJob

  def perform
    AlkWatchdogService.call
  end

end
