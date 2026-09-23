# frozen_string_literal: true

require 'test_helper'

class SusCalculatorTest < ActiveSupport::TestCase

  def with_trends(*rising_flags)
    trends = Array.new(rising_flags.size) { create :trend }
    stub_rising trends, rising_flags do
      yield trends
    end
  end

  def stub_rising(trends, rising_flags, &block)
    return block.call if trends.empty?

    trend, *rest_trends = trends
    rising, *rest_flags = rising_flags
    trend.stub(:rising?, rising) { stub_rising rest_trends, rest_flags, &block }
  end

  test 'is sus when 3 trends are rising' do
    with_trends true, true, true do |trends|
      assert SusCalculator.call(trends:)
    end
  end

  test 'is not sus when fewer than 3 trends are rising' do
    with_trends true, true, false do |trends|
      assert_not SusCalculator.call(trends:)
    end
  end

  test 'is not sus with no trends' do
    assert_not SusCalculator.call(trends: [])
  end

end
