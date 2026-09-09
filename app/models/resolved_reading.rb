# frozen_string_literal: true

class ResolvedReading < ApplicationRecord
  belongs_to :measurement
  has_many :actions, dependent: :destroy

  validates :measurement_id, uniqueness: true
end
