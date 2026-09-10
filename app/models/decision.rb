# frozen_string_literal: true

class Decision < ApplicationRecord

  has_many :decisions_measurements, dependent: :destroy
  has_many :measurements, through: :decisions_measurements

end
