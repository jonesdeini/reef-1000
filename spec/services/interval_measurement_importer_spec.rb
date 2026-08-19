# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntervalMeasurementImporter do
  describe '.import' do
    let :log_json do
      [
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
    end

    before { described_class.import log_json }

    it 'imports only the base_pH input from each entry' do
      expect(Measurement.count).to eq(2)
    end

    it 'stores the value at that entry\'s timestamp' do
      reading = Measurement.find_by recorded_at: '2026-08-17T15:50:00.000Z'

      expect(reading).to have_attributes(metric: Measurement::PH, probe_id: 'base_pH', value: 7.81)
    end

    it 'does not raise on unparseable JSON' do
      expect { described_class.import('not json') }.not_to raise_error
    end
  end

  describe '.import with extra_probe_metrics' do
    let :log_json do
      [{ 'date' => '2026-08-18T13:20:00.000Z', 'inputs' => [{ 'did' => '4_P3', 'value' => 0.3 }] }].to_json
    end

    before { described_class.import log_json, extra_probe_metrics: { '4_P3' => 'kalk_pump_amps' } }

    it 'imports a did that is only known through the extra mapping' do
      expect(Measurement.first).to have_attributes(metric: 'kalk_pump_amps', probe_id: '4_P3', value: 0.3)
    end
  end
end
