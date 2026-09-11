# frozen_string_literal: true

class TrendsMeasurement < ApplicationRecord

  belongs_to :trend
  belongs_to :measurement

end
