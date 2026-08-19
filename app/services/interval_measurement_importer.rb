# frozen_string_literal: true

class IntervalMeasurementImporter
  PROBE_METRICS = {
    'base_pH' => Measurement::PH
  }.freeze

  def self.import(raw_json)
    new.import raw_json
  end

  def import(raw_json)
    JSON.parse(raw_json).each { |entry| import_entry entry }
  rescue JSON::ParserError => e
    Rails.logger.error "IntervalMeasurementImporter: #{e.message}"
  end

  private

  def import_entry(entry)
    entry['inputs'].each { |input| import_input entry['date'], input }
  end

  def import_input(date, input)
    metric = PROBE_METRICS[input['did']]
    return unless metric

    MeasurementWriter.write metric: metric, probe_id: input['did'], value: input['value'], recorded_at: date
  end
end
