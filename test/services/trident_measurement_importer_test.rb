# frozen_string_literal: true

require 'test_helper'

class TridentMeasurementImporterTest < ActiveSupport::TestCase

  setup do
    @log_json = [
      { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_0', 'value' => 7.64, 'confidence' => 0.9719 },
      { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_1', 'value' => 399, 'confidence' => 0.983 },
      { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_2', 'value' => 1467, 'confidence' => 0.981 },
      { 'date' => '2026-08-18T13:20:03.000Z', 'did' => '10_0', 'value' => 7.6, 'confidence' => 0.9452 }
    ].to_json
  end

  test 'imports each trident probe reading as a Measurement' do
    TridentMeasurementImporter.import @log_json

    assert_equal 4, Measurement.count
  end

  test 'stores the value and confidence from the log entry' do
    TridentMeasurementImporter.import @log_json
    alk = Measurement.alk.find_by recorded_at: '2026-08-18T13:20:03.000Z'

    assert_equal '10_0', alk.probe_id
    assert_in_delta 7.6, alk.value.to_f
    assert_in_delta 0.9452, alk.confidence
  end

  test 'is idempotent when the same window is imported twice' do
    TridentMeasurementImporter.import @log_json
    TridentMeasurementImporter.import @log_json

    assert_equal 4, Measurement.count
  end

  test 'ignores an entry with a did that has no known metric mapping' do
    json = [{ 'date' => '2026-08-18T10:19:21.000Z', 'did' => 'base_Temp', 'value' => 78.9 }].to_json

    TridentMeasurementImporter.import json

    assert_equal 0, Measurement.count
  end

  test 'does not raise on unparseable JSON' do
    assert_no_difference -> { Measurement.count } do
      TridentMeasurementImporter.import 'not json'
    end
  end

end
