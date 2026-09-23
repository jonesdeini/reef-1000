# frozen_string_literal: true

require 'test_helper'

class IntervalMeasurementImporterTest < ActiveSupport::TestCase

  setup do
    @log_json = [
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
    IntervalMeasurementImporter.import @log_json
  end

  test 'imports only the base_pH input from each entry' do
    assert_equal 2, Measurement.count
  end

  test "stores the value at that entry's timestamp" do
    reading = Measurement.find_by recorded_at: '2026-08-17T15:50:00.000Z'

    assert_equal Measurement::PH, reading.metric
    assert_equal 'base_pH', reading.probe_id
    assert_in_delta 7.81, reading.value.to_f
  end

  test 'does not raise on unparseable JSON' do
    assert_no_difference -> { Measurement.count } do
      IntervalMeasurementImporter.import 'not json'
    end
  end

  test 'imports a did that is only known through the extra_probe_metrics mapping' do
    Measurement.delete_all
    json = [{ 'date' => '2026-08-18T13:20:00.000Z', 'inputs' => [{ 'did' => '4_P3', 'value' => 0.3 }] }].to_json

    IntervalMeasurementImporter.import json, extra_probe_metrics: { '4_P3' => 'kalk_pump_amps' }

    reading = Measurement.first

    assert_equal 'kalk_pump_amps', reading.metric
    assert_equal '4_P3', reading.probe_id
    assert_in_delta 0.3, reading.value.to_f
  end

end
