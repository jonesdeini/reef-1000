# frozen_string_literal: true

class AlkWatchdogJob < ApplicationJob

  limits_concurrency key: 'alk_watchdog', on_conflict: :discard

  def perform
    AlkWatchdogService.call
  end

end
