# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApexScrapeJob do
  before do
    allow(TridentLogService).to receive(:log).and_return('trident-log-json')
    allow(IntervalLogService).to receive(:log).and_return('interval-log-json')
    allow(ApexStatusService).to receive(:status).and_return('status-json')
    allow(OutletPowerProbeResolver).to receive(:resolve).and_return('4_P3' => Measurement::KALK_PUMP_AMPS)
    allow(TridentMeasurementImporter).to receive(:import)
    allow(IntervalMeasurementImporter).to receive(:import)

    described_class.perform_now
  end

  it 'imports the trident log' do
    expect(TridentMeasurementImporter).to have_received(:import).with('trident-log-json')
  end

  it 'resolves the kalk pump power probes from the live status snapshot' do
    output_name = Rails.application.config.x.apex.kalk_pump_output_name
    metrics = { amps_metric: Measurement::KALK_PUMP_AMPS, watts_metric: Measurement::KALK_PUMP_WATTS }

    expect(OutletPowerProbeResolver).to have_received(:resolve).with('status-json', output_name, **metrics)
  end

  it 'imports the interval log with the resolved probe metrics merged in' do
    expect(IntervalMeasurementImporter).to have_received(:import).with(
      'interval-log-json',
      extra_probe_metrics: { '4_P3' => Measurement::KALK_PUMP_AMPS }
    )
  end
end
