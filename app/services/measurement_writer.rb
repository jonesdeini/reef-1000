# frozen_string_literal: true

class MeasurementWriter
  def self.write(metric:, probe_id:, value:, recorded_at:, confidence: nil)
    Measurement.create_or_find_by! probe_id: probe_id, recorded_at: recorded_at do |measurement|
      measurement.metric = metric
      measurement.value = value
      measurement.confidence = confidence
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "MeasurementWriter: skipped invalid #{metric} reading " \
                       "(probe_id=#{probe_id}, recorded_at=#{recorded_at}): #{e.message}"
  end
end
