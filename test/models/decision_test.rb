# frozen_string_literal: true

require 'test_helper'

class DecisionTest < ActiveSupport::TestCase

  test 'round-trips arbitrary payload through jsonb' do
    decision = create :decision, actions: [{ 'command' => 'off' }]

    assert_equal [{ 'command' => 'off' }], decision.reload.actions
  end

  test 'includes an associated trend in trends' do
    trend = create :trend
    decision = create :decision
    decision.trends << trend

    assert_equal [trend], decision.trends
  end

  test 'removes the association when the associated trend is destroyed' do
    trend = create :trend
    decision = create :decision
    decision.trends << trend

    trend.destroy!

    assert_empty decision.reload.trends
  end

end
