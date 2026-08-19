class Measurement < ApplicationRecord
  ALK = "alk"
  CA = "ca"
  MG = "mg"
  PH = "ph"

  validates :metric, :probe_id, :value, :recorded_at, presence: true
  validates :probe_id, uniqueness: { scope: :recorded_at }

  scope :alk, -> { where(metric: ALK) }
  scope :recent_first, -> { order(recorded_at: :desc) }
end
