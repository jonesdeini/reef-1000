# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Decision do
  it 'round-trips arbitrary payload through jsonb' do
    decision = create :decision, actions: [{ 'command' => 'off' }]

    expect(decision.reload.actions).to eq([{ 'command' => 'off' }])
  end

  context 'with an associated trend' do
    let(:trend) { create :trend }
    let(:decision) { create :decision }

    before { decision.trends << trend }

    it 'includes it in trends' do
      expect(decision.trends).to contain_exactly(trend)
    end

    it 'removes the association when the trend is destroyed' do
      trend.destroy!

      expect(decision.reload.trends).to be_empty
    end
  end
end
