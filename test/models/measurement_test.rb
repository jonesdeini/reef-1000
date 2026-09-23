# frozen_string_literal: true

require 'test_helper'

class MeasurementTest < ActiveSupport::TestCase

  include ActiveSupport::Testing::TimeHelpers

  test 'is invalid with no attributes' do
    measurement = Measurement.new

    assert_not measurement.valid?
  end

  test 'flags metric, probe_id, value, and recorded_at when blank' do
    measurement = Measurement.new
    measurement.valid?

    assert_equal %i[metric probe_id value recorded_at].sort, measurement.errors.attribute_names.sort
  end

  test 'is invalid with a duplicate probe_id/recorded_at pair' do
    probe_id = 'ph'
    recorded_at = Time.current

    freeze_time do
      create(:measurement, probe_id:, recorded_at:)
      duplicate = build(:measurement, probe_id:, recorded_at:)

      assert_not duplicate.valid?
    end
  end

  test 'flags probe_id on a duplicate probe_id/recorded_at pair' do
    probe_id = 'ph'
    recorded_at = Time.current

    freeze_time do
      create(:measurement, probe_id:, recorded_at:)
      duplicate = build(:measurement, probe_id:, recorded_at:)
      duplicate.valid?

      assert_equal ['has already been taken'], duplicate.errors[:probe_id]
    end
  end

  test 'allows the same probe_id at a different recorded_at' do
    probe_id = 'ph'
    create(:measurement, probe_id:)
    non_duplicate = build :measurement, probe_id:, recorded_at: 1.hour.ago

    assert_predicate non_duplicate, :valid?
  end

  test 'plausible_alk includes an alk reading within the plausible range' do
    measurement = create :measurement, metric: Measurement::ALK, value: 8.0

    assert_includes Measurement.plausible_alk, measurement
  end

  test 'plausible_alk excludes an alk reading below the plausible range' do
    measurement = create :measurement, metric: Measurement::ALK, value: 4.9

    assert_not_includes Measurement.plausible_alk, measurement
  end

  test 'plausible_alk excludes an alk reading above the plausible range' do
    measurement = create :measurement, metric: Measurement::ALK, value: 15.1

    assert_not_includes Measurement.plausible_alk, measurement
  end

  test 'plausible_alk excludes a non-alk reading, even within the plausible alk range' do
    measurement = create :measurement, metric: Measurement::PH, probe_id: 'ph', value: 8.0

    assert_not_includes Measurement.plausible_alk, measurement
  end

  test 'plausible_alk still persists an implausible reading - plausibility only filters reads' do
    measurement = build :measurement, metric: Measurement::ALK, value: 999

    assert_predicate measurement, :valid?
  end

end
