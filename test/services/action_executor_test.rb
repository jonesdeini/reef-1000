# frozen_string_literal: true

require 'test_helper'

class ActionExecutorTest < ActiveSupport::TestCase

  test 'sets executed_at on a pending decision' do
    decision = create :decision, executed_at: nil

    ActionExecutor.call

    assert_not_nil decision.reload.executed_at
  end

  test 'logs the action' do
    logged = nil
    create :decision, actions: [{ 'pump' => 'off' }], executed_at: nil

    Rails.logger.stub(:info, ->(&blk) { logged = blk.call }) do
      ActionExecutor.call
    end

    assert_match(/pump.*off/, logged)
  end

  test 'leaves already-executed decisions untouched' do
    decision = create :decision, executed_at: 1.day.ago
    previous_executed_at = decision.executed_at

    ActionExecutor.call

    assert_equal previous_executed_at, decision.reload.executed_at
  end

  test 'leaves undecidable decisions untouched' do
    decision = create :decision, executed_at: nil, undecidable_reason: 'insufficient_measurements'

    ActionExecutor.call

    assert_nil decision.reload.executed_at
  end

end
