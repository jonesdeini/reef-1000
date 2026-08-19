# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MeasurementImporter do
  describe '.import_trident_log' do
    let :log_json do
      [
        { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_0', 'value' => 7.64, 'confidence' => 0.9719 },
        { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_1', 'value' => 399, 'confidence' => 0.983 },
        { 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_2', 'value' => 1467, 'confidence' => 0.981 },
        { 'date' => '2026-08-18T13:20:03.000Z', 'did' => '10_0', 'value' => 7.6, 'confidence' => 0.9452 }
      ].to_json
    end

    context 'with valid entries' do
      before { described_class.import_trident_log log_json }

      it 'imports each trident probe reading as a Measurement' do
        expect(Measurement.count).to eq(4)
      end

      it 'stores the value and confidence from the log entry' do
        alk = Measurement.alk.find_by recorded_at: '2026-08-18T13:20:03.000Z'

        expect(alk).to have_attributes(probe_id: '10_0', value: 7.6, confidence: 0.9452)
      end

      it 'is idempotent when the same window is imported twice' do
        described_class.import_trident_log log_json

        expect(Measurement.count).to eq(4)
      end
    end

    context 'with a did that has no known metric mapping' do
      let(:json) { [{ 'date' => '2026-08-18T10:19:21.000Z', 'did' => 'base_Temp', 'value' => 78.9 }].to_json }

      it 'ignores the entry' do
        described_class.import_trident_log json

        expect(Measurement.count).to eq(0)
      end
    end

    context 'with an implausible value' do
      let(:json) { [{ 'date' => '2026-08-18T10:19:21.000Z', 'did' => '10_0', 'value' => 999 }].to_json }

      it 'does not raise' do
        expect { described_class.import_trident_log(json) }.not_to raise_error
      end

      it 'does not persist the entry' do
        described_class.import_trident_log json

        expect(Measurement.count).to eq(0)
      end
    end

    it 'does not raise on unparseable JSON' do
      expect { described_class.import_trident_log('not json') }.not_to raise_error
    end
  end

  describe '.import_status' do
    let :status_json do
      {
        'status' => {
          'inputs' => [
            { 'did' => 'base_Temp', 'type' => 'Temp', 'name' => 'Tmp', 'value' => 78.8 },
            { 'did' => 'base_pH', 'type' => 'pH', 'name' => 'pH', 'value' => 7.87 }
          ]
        }
      }.to_json
    end

    before { described_class.import_status status_json }

    it 'imports only the base_pH input' do
      expect(Measurement.count).to eq(1)
    end

    it 'maps it to the ph metric' do
      expect(Measurement.first).to have_attributes(metric: Measurement::PH, probe_id: 'base_pH', value: 7.87)
    end
  end
end
