# frozen_string_literal: true

class SusCalculator

  def self.call(**)
    new(**).call
  end

  def initialize(measurements:)
    @measurements = measurements

    @score= 0
  end

  def call
    calculate_trend
  end

  private

  attr_reader :measurements, :start_of_window, :time_x, :value_y

  def calculate_trend
    puts LeastSquaresRegression.call(scope: measurements, x_axis: :recorded_at, y_axis: :value)
  end

end
