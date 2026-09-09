# frozen_string_literal: true

require 'test_helper'

class MeasurementTest < ActiveSupport::TestCase
  def build_measurement(**overrides)
    Measurement.new({
      metric: Measurement::ALK,
      probe_id: '10_0',
      value: 7.6,
      recorded_at: Time.current
    }.merge(overrides))
  end

  test 'is valid with plausible attributes' do
    assert build_measurement.valid?
  end

  test 'is invalid with no attributes' do
    assert_not Measurement.new.valid?
  end

  test 'flags metric, probe_id, value, and recorded_at when blank' do
    measurement = Measurement.new
    measurement.valid?

    assert_equal %i[metric probe_id value recorded_at].sort, measurement.errors.attribute_names.sort
  end

  test 'is invalid with a duplicate probe_id/recorded_at pair' do
    recorded_at = Time.current
    build_measurement(recorded_at: recorded_at).save!

    assert_not build_measurement(recorded_at: recorded_at).valid?
  end

  test 'flags probe_id on a duplicate probe_id/recorded_at pair' do
    recorded_at = Time.current
    build_measurement(recorded_at: recorded_at).save!
    duplicate = build_measurement recorded_at: recorded_at
    duplicate.valid?

    assert duplicate.errors[:probe_id].present?
  end

  test 'allows the same probe_id at a different recorded_at' do
    build_measurement(recorded_at: 1.hour.ago).save!

    assert build_measurement(recorded_at: Time.current).valid?
  end

  test 'rejects an alk value outside 0..30' do
    assert_not build_measurement(metric: Measurement::ALK, value: 31).valid?
  end

  test 'rejects a negative value regardless of metric' do
    assert_not build_measurement(metric: Measurement::PH, value: -1).valid?
  end

  test 'accepts a ph value within 0..14' do
    assert build_measurement(metric: Measurement::PH, probe_id: 'base_pH', value: 7.87).valid?
  end
end
