# frozen_string_literal: true

require 'test_helper'

class LeastSquaresRegressionTest < ActiveSupport::TestCase

  test 'calculates the slope, intercept, and fit for a perfectly linear rise' do
    start = Time.utc 2026, 1, 1
    times = [start, start + 1.hour, start + 2.hours, start + 3.hours]
    values = [8.0, 8.1, 8.2, 8.3]

    result = LeastSquaresRegression.call ordered_points: [times, values]

    assert_in_delta 0.1, result[:slope], 0.0001
    assert_in_delta 8.0, result[:intercept], 0.0001
    assert_in_delta 1.0, result[:r_squared], 0.0001
  end

  test 'calculates a negative slope for a declining trend' do
    start = Time.utc 2026, 1, 1
    times = [start, start + 1.hour, start + 2.hours]
    values = [8.2, 8.1, 8.0]

    result = LeastSquaresRegression.call ordered_points: [times, values]

    assert_in_delta(-0.1, result[:slope], 0.0001)
  end

  test 'fits any 2 points perfectly' do
    start = Time.utc 2026, 1, 1
    times = [start, start + 2.hours]
    values = [7.0, 7.5]

    result = LeastSquaresRegression.call ordered_points: [times, values]

    assert_in_delta 1.0, result[:r_squared]
  end

  test 'has a flat slope and fits perfectly rather than dividing by zero with identical values' do
    start = Time.utc 2026, 1, 1
    times = [start, start + 2.hours]
    values = [8.0, 8.0]

    result = LeastSquaresRegression.call ordered_points: [times, values]

    assert_in_delta 0.0, result[:slope]
    assert_in_delta 1.0, result[:r_squared]
  end

  test 'matches the real slope and r_squared from the 2026-08-25->26 incident data' do
    times = [
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
    values = [7.17, 7.09, 7.14, 7.36, 7.31, 7.29, 7.56, 7.56, 7.81, 7.6, 7.67, 7.68]

    result = LeastSquaresRegression.call ordered_points: [times, values]

    assert_in_delta 0.0235, result[:slope], 0.001
    assert_in_delta 0.8148, result[:r_squared], 0.001
  end

end
