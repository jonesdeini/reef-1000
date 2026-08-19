# frozen_string_literal: true

class Measurement < ApplicationRecord
  ALK = 'alk'
  CA = 'ca'
  MG = 'mg'
  PH = 'ph'
  KALK_PUMP_AMPS = 'kalk_pump_amps'
  KALK_PUMP_WATTS = 'kalk_pump_watts'

  PLAUSIBLE_RANGES = {
    ALK => 0..30,
    CA => 0..1000,
    MG => 0..2000,
    PH => 0..14,
    KALK_PUMP_AMPS => 0..15,
    KALK_PUMP_WATTS => 0..500
  }.freeze

  validates :metric, :probe_id, :value, :recorded_at, presence: true
  validates :probe_id, uniqueness: { scope: :recorded_at }
  validate :value_within_plausible_range

  scope :alk, -> { where(metric: ALK) }
  scope :recent_first, -> { order(recorded_at: :desc) }

  private

  def value_within_plausible_range
    range = PLAUSIBLE_RANGES[metric]
    return if range.nil? || value.nil?

    errors.add :value, "is outside the plausible range for #{metric}" unless range.cover? value
  end
end
