# frozen_string_literal: true

class ActionExecutorJob < ApplicationJob

  limits_concurrency key: 'action_executor', on_conflict: :discard

  def perform
    ActionExecutor.call
  end

end
