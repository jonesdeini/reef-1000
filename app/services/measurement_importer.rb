# frozen_string_literal: true

class MeasurementImporter
  PROBE_METRICS = {
    '10_0' => Measurement::ALK,
    '10_1' => Measurement::CA,
    '10_2' => Measurement::MG,
    'base_pH' => Measurement::PH
  }.freeze

  def self.import_trident_log(raw_json)
    new.import_trident_log raw_json
  end

  def self.import_status(raw_json)
    new.import_status raw_json
  end

  def import_trident_log(raw_json)
    JSON.parse(raw_json).each { |entry| import_trident_entry entry }
  rescue JSON::ParserError => e
    Rails.logger.error "MeasurementImporter#import_trident_log: #{e.message}"
  end

  def import_status(raw_json)
    payload = JSON.parse raw_json
    ph_input = payload.dig('status', 'inputs')&.find { |input| input['did'] == 'base_pH' }
    import_status_entry ph_input if ph_input
  rescue JSON::ParserError => e
    Rails.logger.error "MeasurementImporter#import_status: #{e.message}"
  end

  private

  def import_trident_entry(entry)
    metric = PROBE_METRICS[entry['did']]
    return unless metric

    Measurement.create_or_find_by! probe_id: entry['did'], recorded_at: entry['date'] do |measurement|
      measurement.metric = metric
      measurement.value = entry['value']
      measurement.confidence = entry['confidence']
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "MeasurementImporter: skipped invalid trident entry #{entry.inspect}: #{e.message}"
  end

  def import_status_entry(input)
    metric = PROBE_METRICS[input['did']]
    return unless metric

    Measurement.create! probe_id: input['did'], metric: metric, value: input['value'], recorded_at: Time.current
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "MeasurementImporter: skipped invalid status entry #{input.inspect}: #{e.message}"
  end
end
