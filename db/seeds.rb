# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# A handful of plausible alk readings on the Trident's real ~3h test cadence, for local dev/exploration
# (dashboards, backtesting AlkWatchdogService) without needing a live Apex session. Fixed absolute
# timestamps (not "N.hours.ago") so repeat runs are genuinely idempotent rather than drifting with
# wall-clock time.
[
  [Time.utc(2026, 9, 1, 0, 0, 0), 8.10, 0.9821],
  [Time.utc(2026, 9, 1, 3, 0, 0), 8.05, 0.9902],
  [Time.utc(2026, 9, 1, 6, 0, 0), 7.98, 0.9756],
  [Time.utc(2026, 9, 1, 9, 0, 0), 7.91, 0.9888],
  [Time.utc(2026, 9, 1, 12, 0, 0), 7.85, 0.9931]
].each do |recorded_at, value, confidence|
  Measurement.find_or_create_by!(probe_id: '10_0', recorded_at: recorded_at) do |measurement|
    measurement.metric = Measurement::ALK
    measurement.value = value
    measurement.confidence = confidence
  end
end
