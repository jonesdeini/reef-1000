# frozen_string_literal: true

class LeastSquaresRegression

  def self.call(**)
    new(**).call
  end

  def initialize(ordered_points:)
    start = ordered_points.first.first
    @x = ordered_points.first.map { (it - start) / 1.hour.in_seconds }
    @y = ordered_points.last
    @n = x.count
  end

  def call
    { slope:, intercept:, r_squared: }
  end

  private

  attr_reader :x, :y, :n

  def x_sum
    @x_sum ||= x.sum
  end

  def y_sum
    @y_sum ||= y.sum
  end

  def x_squared
    @x_squared ||= x.map { it * it }
  end

  def x_y_sum
    @x_y_sum ||= x.each_with_index.sum { |x_at_index, index| x_at_index * y[index] }
  end

  def x_sum_squared
    @x_sum_squared ||= x_sum * x_sum
  end

  def slope
    ((n * x_y_sum) - (x_sum * y_sum)) / ((n * x_squared.sum) - x_sum_squared)
  end

  def intercept
    (y_sum - (slope * x_sum)) / n
  end

  def predicted
    @predicted ||= x.map { (slope * it) + intercept }
  end

  def y_mean
    @y_mean ||= y_sum / n
  end

  def residual_sum_of_squares
    @residual_sum_of_squares ||= y.each_with_index.sum { |y_at_index, index| (y_at_index - predicted[index])**2 }
  end

  def total_sum_of_squares
    @total_sum_of_squares ||= y.sum { (it - y_mean)**2 }
  end

  def r_squared
    1 - (residual_sum_of_squares / total_sum_of_squares)
  end

end
