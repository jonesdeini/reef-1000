# frozen_string_literal: true

require 'test_helper'

class AlkWatchdogJobTest < ActiveJob::TestCase

  test 'calls AlkWatchdogService.call' do
    calls = []

    AlkWatchdogService.stub(:call, -> { calls << true }) do
      AlkWatchdogJob.perform_now
    end

    assert_equal 1, calls.size
  end

end
