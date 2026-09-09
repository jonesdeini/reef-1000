# frozen_string_literal: true

require 'test_helper'

class ApexScrapeJobTest < ActiveJob::TestCase
  test 'imports the trident log, resolves the kalk pump probes, and imports the interval log with merged metrics' do
    output_name = Rails.application.config.x.apex.kalk_pump_output_name
    probe_metrics = { '4_P3' => Measurement::KALK_PUMP_AMPS }
    trident_import_calls = []
    resolve_calls = []
    interval_import_calls = []

    TridentLogService.stub :log, 'trident-log-json' do
      IntervalLogService.stub :log, 'interval-log-json' do
        ApexStatusService.stub :status, 'status-json' do
          OutletPowerProbeResolver.stub(:resolve, lambda { |*args|
            resolve_calls << args
            probe_metrics
          }) do
            TridentMeasurementImporter.stub(:import, ->(*args) { trident_import_calls << args }) do
              IntervalMeasurementImporter.stub(:import, ->(*args) { interval_import_calls << args }) do
                ApexScrapeJob.perform_now
              end
            end
          end
        end
      end
    end

    assert_equal [['trident-log-json']], trident_import_calls

    expected_metrics = { amps_metric: Measurement::KALK_PUMP_AMPS, watts_metric: Measurement::KALK_PUMP_WATTS }
    assert_equal [['status-json', output_name, expected_metrics]], resolve_calls

    assert_equal [['interval-log-json', { extra_probe_metrics: probe_metrics }]], interval_import_calls
  end
end
