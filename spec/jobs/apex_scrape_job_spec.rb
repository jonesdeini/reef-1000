# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApexScrapeJob do
  before do
    allow(TridentLogService).to receive(:log).and_return('trident-log-json')
    allow(IntervalLogService).to receive(:log).and_return('interval-log-json')
    allow(TridentMeasurementImporter).to receive(:import)
    allow(IntervalMeasurementImporter).to receive(:import)

    described_class.perform_now
  end

  it 'imports the trident log' do
    expect(TridentMeasurementImporter).to have_received(:import).with('trident-log-json')
  end

  it 'imports the interval log' do
    expect(IntervalMeasurementImporter).to have_received(:import).with('interval-log-json')
  end
end
