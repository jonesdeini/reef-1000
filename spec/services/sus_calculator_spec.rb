# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SusCalculator do
  describe '.call' do
    def alk_reading(value:, confidence:, recorded_at:)
      create :measurement, metric: Measurement::ALK, value:, confidence:, recorded_at:
    end

    context 'with the real 2026-08-25->26 incident data' do
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

      it 'calculates a positive trend' do
        result = described_class.call(measurements: Measurement.alk.order(:recorded_at))

        expect(result).to be_positive
      end
    end
  end
end
