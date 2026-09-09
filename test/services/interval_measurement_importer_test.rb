# frozen_string_literal: true

require 'test_helper'

class IntervalMeasurementImporterTest < ActiveSupport::TestCase
  test "imports only the base_pH input from each entry, at that entry's timestamp" do
    log_json = [
      {
        'date' => '2026-08-17T15:40:00.000Z',
        'inputs' => [
          { 'did' => 'base_Temp', 'value' => 78.9 },
          { 'did' => 'base_pH', 'value' => 7.82 },
          { 'did' => 'base_ORP', 'value' => 0 }
        ]
      },
      {
        'date' => '2026-08-17T15:50:00.000Z',
        'inputs' => [
          { 'did' => 'base_Temp', 'value' => 78.9 },
          { 'did' => 'base_pH', 'value' => 7.81 }
        ]
      }
    ].to_json

    IntervalMeasurementImporter.import log_json

    assert_equal 2, Measurement.count

    reading = Measurement.find_by recorded_at: '2026-08-17T15:50:00.000Z'
    assert_equal Measurement::PH, reading.metric
    assert_equal 'base_pH', reading.probe_id
    assert_equal 7.81, reading.value
  end

  test 'does not raise on unparseable JSON' do
    IntervalMeasurementImporter.import 'not json'

    assert_equal 0, Measurement.count
  end

  test 'imports a did that is only known through the extra_probe_metrics mapping' do
    log_json = [
      { 'date' => '2026-08-18T13:20:00.000Z', 'inputs' => [{ 'did' => '4_P3', 'value' => 0.3 }] }
    ].to_json

    IntervalMeasurementImporter.import log_json, extra_probe_metrics: { '4_P3' => 'kalk_pump_amps' }

    measurement = Measurement.first
    assert_equal 'kalk_pump_amps', measurement.metric
    assert_equal '4_P3', measurement.probe_id
    assert_equal 0.3, measurement.value
  end
end
