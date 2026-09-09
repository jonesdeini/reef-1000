# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Action do
  def build_resolved_reading
    measurement = Measurement.create!(
      metric: Measurement::ALK,
      probe_id: '10_0',
      value: 7.6,
      recorded_at: Time.current
    )
    ResolvedReading.create! measurement: measurement
  end

  it 'is valid with a resolved_reading, equipment, and payload' do
    attrs = { resolved_reading: build_resolved_reading, equipment: 'kalk_pump', payload: { 'command' => 'off' } }

    expect(described_class.new(attrs)).to be_valid
  end

  it 'is invalid without an equipment' do
    action = described_class.new resolved_reading: build_resolved_reading, payload: { 'command' => 'off' }

    expect(action).not_to be_valid
  end

  it 'is invalid without a resolved_reading' do
    action = described_class.new equipment: 'kalk_pump', payload: { 'command' => 'off' }

    expect(action).not_to be_valid
  end

  it 'defaults payload to an empty hash' do
    action = described_class.create! resolved_reading: build_resolved_reading, equipment: 'kalk_pump'

    expect(action.payload).to eq({})
  end

  it 'round-trips arbitrary payload through jsonb' do
    payload = { 'command' => 'off', 'reason' => 'seems_high' }
    action = described_class.create! resolved_reading: build_resolved_reading, equipment: 'kalk_pump', payload: payload

    expect(action.reload.payload).to eq(payload)
  end

  it 'defaults executed_at to nil' do
    action = described_class.create! resolved_reading: build_resolved_reading, equipment: 'kalk_pump'

    expect(action.executed_at).to be_nil
  end
end
