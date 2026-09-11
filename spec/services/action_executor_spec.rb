# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionExecutor do
  describe '.call' do
    it 'sets executed_at on a pending decision' do
      decision = create :decision, executed_at: nil

      described_class.call

      expect(decision.reload.executed_at).not_to be_nil
    end

    it 'logs the action' do
      logged = nil
      allow(Rails.logger).to receive(:info) { |&block| logged = block.call }
      create :decision, action: { 'pump' => 'off' }, executed_at: nil

      described_class.call

      expect(logged).to match(/pump.*off/)
    end

    it 'leaves already-executed decisions untouched' do
      decision = create :decision, executed_at: 1.day.ago

      expect { described_class.call }.not_to(change { decision.reload.executed_at })
    end
  end
end
