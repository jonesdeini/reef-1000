# frozen_string_literal: true

require 'test_helper'

class ActionExecutorJobTest < ActiveJob::TestCase

  test 'calls ActionExecutor.call' do
    calls = []

    ActionExecutor.stub(:call, -> { calls << true }) do
      ActionExecutorJob.perform_now
    end

    assert_equal 1, calls.size
  end

end
