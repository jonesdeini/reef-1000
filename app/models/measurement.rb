# frozen_string_literal: true

class Measurement < ApplicationRecord

  ALK = 'alk'
  CA = 'ca'
  MG = 'mg'
  PH = 'ph'
  KALK_PUMP_AMPS = 'kalk_pump_amps'
  KALK_PUMP_WATTS = 'kalk_pump_watts'

  PLAUSIBLE_ALK_RANGE = 5..15

  has_many :trends_measurements, dependent: :destroy
  has_many :trends, through: :trends_measurements

  validates :metric, :probe_id, :value, :recorded_at, presence: true
  validates :probe_id, uniqueness: { scope: :recorded_at }

  scope :alk, -> { where(metric: ALK) }
  scope :plausible_alk, -> { alk.where(value: PLAUSIBLE_ALK_RANGE) }

end
