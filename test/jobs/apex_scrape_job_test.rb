# frozen_string_literal: true

require 'test_helper'

class ApexScrapeJobTest < ActiveJob::TestCase

  setup do
    @trident_import_calls = []
    @resolve_calls = []
    @interval_import_calls = []
    @alk_watchdog_calls = []

    TridentLogService.stub :log, 'trident-log-json' do
      IntervalLogService.stub :log, 'interval-log-json' do
        ApexStatusService.stub :status, 'status-json' do
          OutletPowerProbeResolver.stub(:resolve, lambda { |*args|
            @resolve_calls << args
            { '4_P3' => Measurement::KALK_PUMP_AMPS }
          }) do
            TridentMeasurementImporter.stub(:import, ->(*args) { @trident_import_calls << args }) do
              IntervalMeasurementImporter.stub(:import, ->(*args) { @interval_import_calls << args }) do
                AlkWatchdogJob.stub(:perform_later, -> { @alk_watchdog_calls << true }) do
                  ApexScrapeJob.perform_now
                end
              end
            end
          end
        end
      end
    end
  end

  test 'imports the trident log' do
    assert_equal [['trident-log-json']], @trident_import_calls
  end

  test 'resolves the kalk pump power probes from the live status snapshot' do
    output_name = Rails.application.config.x.apex.kalk_pump_output_name
    metrics = { amps_metric: Measurement::KALK_PUMP_AMPS, watts_metric: Measurement::KALK_PUMP_WATTS }

    assert_equal [['status-json', output_name, metrics]], @resolve_calls
  end

  test 'imports the interval log with the resolved probe metrics merged in' do
    expected_metrics = { extra_probe_metrics: { '4_P3' => Measurement::KALK_PUMP_AMPS } }

    assert_equal [['interval-log-json', expected_metrics]], @interval_import_calls
  end

  test 'enqueues the alk watchdog job after a successful scrape' do
    assert_equal 1, @alk_watchdog_calls.size
  end

end
