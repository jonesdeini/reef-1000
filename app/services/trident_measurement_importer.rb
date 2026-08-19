# frozen_string_literal: true

class TridentMeasurementImporter
  PROBE_METRICS = {
    '10_0' => Measurement::ALK,
    '10_1' => Measurement::CA,
    '10_2' => Measurement::MG
  }.freeze

  def self.import(raw_json)
    new.import raw_json
  end

  def import(raw_json)
    JSON.parse(raw_json).each { |entry| import_entry entry }
  rescue JSON::ParserError => e
    Rails.logger.error "TridentMeasurementImporter: #{e.message}"
  end

  private

  def import_entry(entry)
    metric = PROBE_METRICS[entry['did']]
    return unless metric

    MeasurementWriter.write(
      metric: metric,
      probe_id: entry['did'],
      value: entry['value'],
      confidence: entry['confidence'],
      recorded_at: entry['date']
    )
  end
end
