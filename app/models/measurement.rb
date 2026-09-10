# frozen_string_literal: true

class Measurement < ApplicationRecord

  ALK = 'alk'
  CA = 'ca'
  MG = 'mg'
  PH = 'ph'
  KALK_PUMP_AMPS = 'kalk_pump_amps'
  KALK_PUMP_WATTS = 'kalk_pump_watts'

  has_many :decisions_measurements, dependent: :destroy
  has_many :decisions, through: :decisions_measurements

  validates :metric, :probe_id, :value, :recorded_at, presence: true
  validates :probe_id, uniqueness: { scope: :recorded_at }

  scope :alk, -> { where(metric: ALK) }

end
