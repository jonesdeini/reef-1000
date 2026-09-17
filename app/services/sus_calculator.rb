# frozen_string_literal: true

class SusCalculator

  class << self

    def call(**)
      new(**).call
    end
    alias sus? call

  end

  def initialize(trends:)
    @trends = trends
  end

  def call
    trends.sum { |trend| trend.rising? ? 34 : 0 } >= 100
  end
  alias sus? call

  private

  attr_reader :trends

end
