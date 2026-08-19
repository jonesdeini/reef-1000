# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApexScrapeJob do
  before do
    allow(TridentLogService).to receive(:log).and_return('trident-log-json')
    allow(ApexStatusService).to receive(:status).and_return('status-json')
    allow(MeasurementImporter).to receive(:import_trident_log)
    allow(MeasurementImporter).to receive(:import_status)

    described_class.perform_now
  end

  it 'imports the trident log' do
    expect(MeasurementImporter).to have_received(:import_trident_log).with('trident-log-json')
  end

  it 'imports the current status' do
    expect(MeasurementImporter).to have_received(:import_status).with('status-json')
  end
end
