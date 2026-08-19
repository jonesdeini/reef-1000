# frozen_string_literal: true

class IntervalMeasurementImporter
  DEFAULT_PROBE_METRICS = {
    'base_pH' => Measurement::PH
  }.freeze

  def self.import(raw_json, extra_probe_metrics: {})
    new(extra_probe_metrics).import raw_json
  end

  def initialize(extra_probe_metrics = {})
    @probe_metrics = DEFAULT_PROBE_METRICS.merge extra_probe_metrics
  end

  def import(raw_json)
    JSON.parse(raw_json).each { |entry| import_entry entry }
  rescue JSON::ParserError => e
    Rails.logger.error "IntervalMeasurementImporter: #{e.message}"
  end

  private

  attr_reader :probe_metrics

  def import_entry(entry)
    entry['inputs'].each { |input| import_input entry['date'], input }
  end

  def import_input(date, input)
    metric = probe_metrics[input['did']]
    return unless metric

    MeasurementWriter.write metric: metric, probe_id: input['did'], value: input['value'], recorded_at: date
  end
end
