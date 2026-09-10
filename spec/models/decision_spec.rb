# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Decision do
  it 'round-trips arbitrary payload through jsonb' do
    decision = create :decision, action: { 'command' => 'off' }

    expect(decision.reload.action).to eq('command' => 'off')
  end

  context 'with an associated measurement' do
    let(:measurement) { create :measurement }
    let(:decision) { create :decision }

    before { decision.measurements << measurement }

    it 'includes it in measurements' do
      expect(decision.measurements).to contain_exactly(measurement)
    end

    it 'removes the association when the measurement is destroyed' do
      measurement.destroy!

      expect(decision.reload.measurements).to be_empty
    end
  end
end
