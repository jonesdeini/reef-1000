# frozen_string_literal: true

require 'test_helper'

class AlkWatchdogServiceTest < ActiveSupport::TestCase

  include ActiveSupport::Testing::TimeHelpers

  def alk_reading(value:, confidence: 0.98, recorded_at: Time.current)
    create :measurement, metric: Measurement::ALK, value:, confidence:, recorded_at:
  end

  def stub_rising(trends, rising_flags, &block)
    return block.call if trends.empty?

    trend, *rest_trends = trends
    rising, *rest_flags = rising_flags
    trend.stub(:rising?, rising) { stub_rising rest_trends, rest_flags, &block }
  end

  def with_last3_trends(*rising_flags, &)
    trends = Array.new(rising_flags.size) { create :trend }
    stub_rising trends, rising_flags do
      Trend.stub(:last3, trends, &)
    end
  end

  test 'commands the pump off when sus' do
    with_last3_trends true, true, true do
      alk_reading value: 8.0
      alk_reading value: 8.05

      AlkWatchdogService.call

      assert_equal [{ 'kalk_pump' => 'off' }], Decision.last.actions
    end
  end

  test 'takes no action when not sus' do
    with_last3_trends false, false do
      alk_reading value: 8.0
      alk_reading value: 8.05

      AlkWatchdogService.call

      assert_equal [], Decision.last.actions
    end
  end

  test 'creates a decision when there is no alk data' do
    assert_difference -> { Decision.count }, 1 do
      AlkWatchdogService.call
    end
  end

  test 'takes no action and marks the decision undecidable when there is no alk data' do
    AlkWatchdogService.call

    assert_equal [], Decision.last.actions
    assert_equal 'insufficient_measurements', Decision.last.undecidable_reason
  end

  test 'takes no action and marks the decision undecidable when there is only one alk reading' do
    alk_reading value: 8.0

    AlkWatchdogService.call

    assert_equal [], Decision.last.actions
    assert_equal 'insufficient_measurements', Decision.last.undecidable_reason
  end

  test 'ignores a measurement recorded after the point in time being evaluated' do
    travel_to(Time.utc(2026, 1, 1, 12, 0, 0)) { alk_reading value: 8.0 }
    alk_reading value: 8.0, recorded_at: Time.utc(2026, 1, 1, 18, 0, 0)

    travel_to(Time.utc(2026, 1, 1, 12, 0, 0)) { AlkWatchdogService.call }

    assert_equal [], Decision.last.actions
    assert_equal 'insufficient_measurements', Decision.last.undecidable_reason
  end

  test 'takes no action and marks the decision undecidable when the most recent reading is stale' do
    alk_reading value: 8.0, recorded_at: 6.hours.ago
    alk_reading value: 8.05, recorded_at: 5.5.hours.ago

    AlkWatchdogService.call

    assert_equal [], Decision.last.actions
    assert_equal 'stale_data', Decision.last.undecidable_reason
  end

  test 'persists a flat Trend when alk readings have no variance, rather than skipping it' do
    alk_reading value: 8.0, recorded_at: 2.hours.ago
    alk_reading value: 8.0, recorded_at: 1.hour.ago

    AlkWatchdogService.call

    assert_in_delta 0.0, Trend.last.slope
    assert_in_delta 1.0, Trend.last.r_squared
  end

  test 'takes no action when alk readings have no variance, since a flat trend is never rising' do
    alk_reading value: 8.0, recorded_at: 2.hours.ago
    alk_reading value: 8.0, recorded_at: 1.hour.ago

    AlkWatchdogService.call

    assert_equal [], Decision.last.actions
  end

  test 'always creates a new decision, even when nothing changed' do
    alk_reading value: 8.0

    assert_difference -> { Decision.count }, 2 do
      2.times { AlkWatchdogService.call }
    end
  end

  test 'takes no action against the real 2026-08-25->27 incident data, since it never crossed the alk threshold' do
    [
      [Time.utc(2026, 8, 25, 19, 20, 42), 7.17, 0.9637],
      [Time.utc(2026, 8, 25, 20, 3, 32), 7.09, 0.9879],
      [Time.utc(2026, 8, 25, 22, 19, 30), 7.14, 0.9925],
      [Time.utc(2026, 8, 26, 0, 36, 14), 7.36, 0.9741],
      [Time.utc(2026, 8, 26, 1, 10, 20), 7.31, 0.9933],
      [Time.utc(2026, 8, 26, 4, 19, 30), 7.29, 0.9967],
      [Time.utc(2026, 8, 26, 7, 10, 6), 7.56, 0.9629],
      [Time.utc(2026, 8, 26, 10, 19, 28), 7.56, 0.9996],
      [Time.utc(2026, 8, 26, 13, 10, 6), 7.81, 0.9673],
      [Time.utc(2026, 8, 26, 16, 19, 39), 7.6, 0.9731],
      [Time.utc(2026, 8, 26, 19, 10, 13), 7.67, 0.9906],
      [Time.utc(2026, 8, 26, 22, 19, 27), 7.68, 0.9987]
    ].each { |recorded_at, value, confidence| alk_reading recorded_at:, value:, confidence: }

    travel_to Time.utc(2026, 8, 27, 0, 0, 0) do
      AlkWatchdogService.call
    end

    assert_equal [], Decision.last.actions
  end

end
