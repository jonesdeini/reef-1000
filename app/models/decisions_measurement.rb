# frozen_string_literal: true

class DecisionsMeasurement < ApplicationRecord

  belongs_to :decision
  belongs_to :measurement

end
