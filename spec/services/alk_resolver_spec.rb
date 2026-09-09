# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlkResolver do
  describe '.analyze' do
    def reading(value:, confidence: 0.98, recorded_at: Time.current)
      Measurement.new(
        metric: Measurement::ALK,
        probe_id: '10_0',
        value: value,
        confidence: confidence,
        recorded_at: recorded_at
      )
    end

    context 'when confidence is too low' do
      subject :result do
        described_class.analyze readings: [reading(value: 7.6, confidence: 0.5)], pump_running_recently: false
      end

      it 'produces no action' do
        expect(result[:actions]).to be_empty
      end

      it 'marks the reading as not confident' do
        expect(result[:metadata]['confident']).to be false
      end
    end

    context 'when the latest reading is stale' do
      subject :result do
        described_class.analyze readings: [reading(value: 7.6, recorded_at: 1.day.ago)], pump_running_recently: false
      end

      it 'produces no action' do
        expect(result[:actions]).to be_empty
      end

      it 'marks the reading as not fresh' do
        expect(result[:metadata]['fresh']).to be false
      end
    end

    it 'produces an off action when the reading is above target + deadband' do
      readings = [reading(value: 7.9), reading(value: 8.5)]

      result = described_class.analyze readings: readings, pump_running_recently: true

      expect(result[:actions]).to contain_exactly(
        { equipment: 'kalk_pump', payload: { 'command' => 'off', 'reason' => 'above_band' } }
      )
    end

    context 'when the reading is below target - deadband' do
      subject :result do
        described_class.analyze readings: [reading(value: 7.9), reading(value: 7.5)], pump_running_recently: false
      end

      it 'produces no action' do
        expect(result[:actions]).to be_empty
      end

      it 'marks the reading as below band' do
        expect(result[:metadata]['below_band']).to be true
      end
    end

    it 'produces no action when the reading is within the target band' do
      readings = [reading(value: 7.9), reading(value: 8.0)]

      result = described_class.analyze readings: readings, pump_running_recently: true

      expect(result[:actions]).to be_empty
    end

    context 'when there are multiple readings to compute a trend from' do
      subject :result do
        described_class.analyze readings: [reading(value: 7.5), reading(value: 8.0)], pump_running_recently: false
      end

      it 'computes the trend direction' do
        expect(result[:metadata]['trend_direction']).to eq('up')
      end

      it 'computes the trend magnitude' do
        expect(result[:metadata]['trend_magnitude']).to eq(0.5)
      end
    end

    it 'records pump_running_recently in metadata' do
      result = described_class.analyze readings: [reading(value: 8.0)], pump_running_recently: true

      expect(result[:metadata]['pump_running_recently']).to be true
    end
  end

  describe '.resolve' do
    def create_alk_measurement(value:, recorded_at: Time.current, confidence: 0.98)
      Measurement.create!(
        metric: Measurement::ALK,
        probe_id: '10_0',
        value: value,
        confidence: confidence,
        recorded_at: recorded_at
      )
    end

    it 'does nothing when there is no alk measurement at all' do
      expect { described_class.resolve }.not_to change(ResolvedReading, :count)
    end

    context 'when there are multiple unresolved alk measurements' do
      before { create_alk_measurement value: 7.9, recorded_at: 2.hours.ago }

      let!(:latest) { create_alk_measurement value: 8.5, recorded_at: Time.current }

      it 'resolves only the current latest one' do
        described_class.resolve

        expect(ResolvedReading.sole.measurement).to eq(latest)
      end
    end

    context 'when the latest reading is above band' do
      before { create_alk_measurement value: 8.5, recorded_at: Time.current }

      it 'creates the matching action' do
        described_class.resolve

        expect(Action.sole.equipment).to eq('kalk_pump')
      end
    end

    it 'creates no action when the latest reading is within band' do
      create_alk_measurement value: 8.0, recorded_at: Time.current

      described_class.resolve

      expect(Action.count).to eq(0)
    end

    it 'is a no-op when the latest alk measurement is already resolved' do
      latest = create_alk_measurement value: 8.5, recorded_at: Time.current
      ResolvedReading.create! measurement: latest

      expect { described_class.resolve }.not_to change(ResolvedReading, :count)
    end

    it 'never resolves an older measurement, even if unresolved' do
      old = create_alk_measurement value: 8.5, recorded_at: 1.day.ago
      create_alk_measurement value: 8.0, recorded_at: Time.current

      described_class.resolve

      expect(ResolvedReading.find_by(measurement: old)).to be_nil
    end
  end
end
