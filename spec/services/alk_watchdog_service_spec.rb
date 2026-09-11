# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlkWatchdogService do
  include ActiveSupport::Testing::TimeHelpers

  describe '.call' do
    def alk_reading(value:, confidence: 0.98, recorded_at: Time.current)
      create :measurement, metric: Measurement::ALK, value:, confidence:, recorded_at:
    end

    def pump_reading(value:, recorded_at: Time.current)
      create :measurement, metric: Measurement::KALK_PUMP_WATTS, probe_id: '4_P11', value:, recorded_at:
    end

    context 'when sus' do
      before do
        trends = Array.new(3) { create(:trend).tap { allow(it).to receive(:rising?).and_return(true) } }
        allow(Trend).to receive(:last3).and_return(trends)
        alk_reading value: 8.0
        alk_reading value: 8.05
      end

      it 'commands the pump off' do
        described_class.call

        expect(Decision.last.actions).to eq([{ 'kalk_pump' => 'off' }])
      end
    end

    context 'when not sus' do
      before do
        trends = [
          create(:trend).tap { allow(it).to receive(:rising?).and_return(false) },
          create(:trend).tap { allow(it).to receive(:rising?).and_return(false) }
        ]
        allow(Trend).to receive(:last3).and_return(trends)
        alk_reading value: 8.0
        alk_reading value: 8.05
      end

      it 'takes no action' do
        described_class.call

        expect(Decision.last.actions).to eq([])
      end
    end

    it 'creates a decision when there is no alk data' do
      expect { described_class.call }.to change(Decision, :count).by(1)
    end

    it 'takes no action and marks the decision undecidable when there is no alk data' do
      described_class.call

      expect(Decision.last).to have_attributes(actions: [], undecidable_reason: 'insufficient_measurements')
    end

    it 'takes no action and marks the decision undecidable when there is only one alk reading' do
      alk_reading value: 8.0

      described_class.call

      expect(Decision.last).to have_attributes(actions: [], undecidable_reason: 'insufficient_measurements')
    end

    it 'ignores a measurement recorded after the point in time being evaluated' do
      travel_to(Time.utc(2026, 1, 1, 12, 0, 0)) { alk_reading value: 8.0 }
      alk_reading value: 8.0, recorded_at: Time.utc(2026, 1, 1, 18, 0, 0)

      travel_to(Time.utc(2026, 1, 1, 12, 0, 0)) { described_class.call }

      expect(Decision.last).to have_attributes(actions: [], undecidable_reason: 'insufficient_measurements')
    end

    it 'takes no action and marks the decision undecidable when the most recent reading is stale' do
      alk_reading value: 8.0, recorded_at: 6.hours.ago
      alk_reading value: 8.05, recorded_at: 5.5.hours.ago

      described_class.call

      expect(Decision.last).to have_attributes(actions: [], undecidable_reason: 'stale_data')
    end

    it 'always creates a new decision, even when nothing changed' do
      alk_reading value: 8.0

      expect { 2.times { described_class.call } }.to change(Decision, :count).by(2)
    end

    context 'with the real 2026-08-25->27 incident data' do
      before do
        [
          [Time.utc(2026, 8, 25, 19, 20, 42), 7.17, 0.9637],
          [Time.utc(2026, 8, 25, 20, 3, 32), 7.09, 0.9879],
          [Time.utc(2026, 8, 25, 22, 19, 30), 7.14, 0.9925],
          [Time.utc(2026, 8, 26, 0, 36, 14), 7.36, 0.9741],
          [Time.utc(2026, 8, 26, 1, 10, 20), 7.31, 0.9933],
          [Time.utc(2026, 8, 26, 4, 19, 30), 7.29, 0.9967],
          [Time.utc(2026, 8, 26, 7, 10, 6), 7.56, 0.9629],
          [Time.utc(2026, 8, 26, 10, 19, 28), 7.56, 0.9996],
          [Time.utc(2026, 8, 26, 13, 10, 6), 7.81, 0.9673],
          [Time.utc(2026, 8, 26, 16, 19, 39), 7.6, 0.9731],
          [Time.utc(2026, 8, 26, 19, 10, 13), 7.67, 0.9906],
          [Time.utc(2026, 8, 26, 22, 19, 27), 7.68, 0.9987]
        ].each { |recorded_at, value, confidence| alk_reading recorded_at:, value:, confidence: }
      end

      it 'takes no action, because the real incident never actually crossed the alk threshold' do
        travel_to Time.utc(2026, 8, 27, 0, 0, 0) do
          described_class.call
        end

        expect(Decision.last.actions).to eq([])
      end
    end
  end
end
