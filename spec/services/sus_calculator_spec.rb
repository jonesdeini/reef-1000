# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SusCalculator do
  describe '.call' do
    def trend(rising:)
      create(:trend).tap { |t| allow(t).to receive(:rising?).and_return(rising) }
    end

    it 'is sus when 3 trends are rising' do
      trends = [trend(rising: true), trend(rising: true), trend(rising: true)]

      expect(described_class.call(trends:)).to be true
    end

    it 'is not sus when fewer than 3 trends are rising' do
      trends = [trend(rising: true), trend(rising: true), trend(rising: false)]

      expect(described_class.call(trends:)).to be false
    end

    it 'is not sus with no trends' do
      expect(described_class.call(trends: [])).to be false
    end
  end
end
