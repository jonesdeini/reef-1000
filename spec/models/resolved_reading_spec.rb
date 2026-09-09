# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolvedReading do
  def build_measurement(**overrides)
    Measurement.create!({
      metric: Measurement::ALK,
      probe_id: '10_0',
      value: 7.6,
      recorded_at: Time.current
    }.merge(overrides))
  end

  it 'is valid with a measurement' do
    resolved_reading = described_class.new measurement: build_measurement

    expect(resolved_reading).to be_valid
  end

  it 'is invalid without a measurement' do
    resolved_reading = described_class.new

    expect(resolved_reading).not_to be_valid
  end

  it 'defaults metadata to an empty hash' do
    resolved_reading = described_class.create! measurement: build_measurement

    expect(resolved_reading.metadata).to eq({})
  end

  it 'round-trips arbitrary metadata through jsonb' do
    resolved_reading = described_class.create!(
      measurement: build_measurement,
      metadata: { 'trend_direction' => 'down', 'trend_magnitude' => 0.3 }
    )

    expect(resolved_reading.reload.metadata).to eq('trend_direction' => 'down', 'trend_magnitude' => 0.3)
  end

  it 'enforces one resolution per measurement' do
    measurement = build_measurement
    described_class.create! measurement: measurement

    expect { described_class.create!(measurement: measurement) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'has many actions' do
    resolved_reading = described_class.create! measurement: build_measurement
    resolved_reading.actions.create! equipment: 'kalk_pump', payload: { 'command' => 'off' }

    expect(resolved_reading.actions.count).to eq(1)
  end
end
