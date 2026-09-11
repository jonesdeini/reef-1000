# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeastSquaresRegression do
  describe '.call' do
    context 'with a perfectly linear rise' do
      let(:start) { Time.utc 2026, 1, 1 }
      let(:times) { [start, start + 1.hour, start + 2.hours, start + 3.hours] }
      let(:values) { [8.0, 8.1, 8.2, 8.3] }
      let(:result) { described_class.call ordered_points: [times, values] }

      it 'calculates the slope' do
        expect(result[:slope]).to be_within(0.0001).of(0.1)
      end

      it 'calculates the intercept' do
        expect(result[:intercept]).to be_within(0.0001).of(8.0)
      end

      it 'fits perfectly' do
        expect(result[:r_squared]).to be_within(0.0001).of(1.0)
      end
    end

    it 'calculates a negative slope for a declining trend' do
      start = Time.utc 2026, 1, 1
      times = [start, start + 1.hour, start + 2.hours]
      values = [8.2, 8.1, 8.0]

      result = described_class.call ordered_points: [times, values]

      expect(result[:slope]).to be_within(0.0001).of(-0.1)
    end

    it 'fits any 2 points perfectly' do
      start = Time.utc 2026, 1, 1
      times = [start, start + 2.hours]
      values = [7.0, 7.5]

      result = described_class.call ordered_points: [times, values]

      expect(result[:r_squared]).to eq(1.0)
    end

    context 'with the real 2026-08-25->26 incident data' do
      let :times do
        [
          Time.utc(2026, 8, 25, 19, 20, 42),
          Time.utc(2026, 8, 25, 20, 3, 32),
          Time.utc(2026, 8, 25, 22, 19, 30),
          Time.utc(2026, 8, 26, 0, 36, 14),
          Time.utc(2026, 8, 26, 1, 10, 20),
          Time.utc(2026, 8, 26, 4, 19, 30),
          Time.utc(2026, 8, 26, 7, 10, 6),
          Time.utc(2026, 8, 26, 10, 19, 28),
          Time.utc(2026, 8, 26, 13, 10, 6),
          Time.utc(2026, 8, 26, 16, 19, 39),
          Time.utc(2026, 8, 26, 19, 10, 13),
          Time.utc(2026, 8, 26, 22, 19, 27)
        ]
      end
      let(:values) { [7.17, 7.09, 7.14, 7.36, 7.31, 7.29, 7.56, 7.56, 7.81, 7.6, 7.67, 7.68] }
      let(:result) { described_class.call ordered_points: [times, values] }

      it 'matches the real slope' do
        expect(result[:slope]).to be_within(0.001).of(0.0235)
      end

      it 'matches the real r_squared' do
        expect(result[:r_squared]).to be_within(0.001).of(0.8148)
      end
    end
  end
end
