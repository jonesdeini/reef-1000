# frozen_string_literal: true

require 'test_helper'

class TrendTest < ActiveSupport::TestCase

  test 'rising? is true when slope and r_squared both clear their thresholds' do
    trend = build :trend, slope: 0.03, r_squared: 0.8

    assert_predicate trend, :rising?
  end

  test 'rising? is false when slope is below the threshold, even with a tight fit' do
    trend = build :trend, slope: 0.005, r_squared: 0.95

    assert_not trend.rising?
  end

  test 'rising? is false when r_squared is below the threshold, even with a large slope' do
    trend = build :trend, slope: 0.1, r_squared: 0.1

    assert_not trend.rising?
  end

  test 'rising? is false when slope is negative, regardless of fit' do
    trend = build :trend, slope: -0.05, r_squared: 0.95

    assert_not trend.rising?
  end

  test 'rising? is false right at the slope threshold (strictly greater than, not equal)' do
    threshold = Rails.application.config.x.apex.alk_slope_threshold
    trend = build :trend, slope: threshold, r_squared: 0.9

    assert_not trend.rising?
  end

end
