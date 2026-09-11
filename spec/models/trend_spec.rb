# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trend do
  describe '#rising?' do
    it 'is true when slope and r_squared both clear their thresholds' do
      trend = build :trend, slope: 0.03, r_squared: 0.8

      expect(trend).to be_rising
    end

    it 'is false when slope is below the threshold, even with a tight fit' do
      trend = build :trend, slope: 0.005, r_squared: 0.95

      expect(trend).not_to be_rising
    end

    it 'is false when r_squared is below the threshold, even with a large slope' do
      trend = build :trend, slope: 0.1, r_squared: 0.1

      expect(trend).not_to be_rising
    end

    it 'is false when slope is negative, regardless of fit' do
      trend = build :trend, slope: -0.05, r_squared: 0.95

      expect(trend).not_to be_rising
    end

    it 'is false right at the slope threshold (strictly greater than, not equal)' do
      threshold = Rails.application.config.x.apex.alk_slope_threshold
      trend = build :trend, slope: threshold, r_squared: 0.9

      expect(trend).not_to be_rising
    end
  end
end
