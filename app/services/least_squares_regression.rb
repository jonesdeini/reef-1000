class LeastSquaresRegression

  def self.call(**)
    new(**).call
  end

  def initialize(scope:, x_axis:, y_axis:)
    points = scope.pluck(x_axis, y_axis).transpose
    start = points.first.first
    @x = points.first.map { it - start }
    @y = points.last
    @n = x.count
  end

  def call
    { slope:, intercept: }
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
    (n * x_y_sum - x_sum * y_sum) / (n * x_squared.sum - x_sum_squared)
  end

  def intercept
    (y_sum - slope * x_sum) / n
  end

end
