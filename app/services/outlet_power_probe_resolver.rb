# frozen_string_literal: true

class OutletPowerProbeResolver
  def self.resolve(status_json, output_name, amps_metric:, watts_metric:)
    new(status_json).resolve output_name, amps_metric: amps_metric, watts_metric: watts_metric
  end

  def initialize(status_json)
    @inputs = JSON.parse(status_json).dig('status', 'inputs') || []
  rescue JSON::ParserError
    @inputs = []
  end

  def resolve(output_name, amps_metric:, watts_metric:)
    {
      "#{output_name}A" => amps_metric,
      "#{output_name}W" => watts_metric
    }.filter_map { |name, metric| [find_did(name), metric] if find_did name }.to_h
  end

  private

  attr_reader :inputs

  def find_did(name)
    inputs.find { |input| input['name'] == name }&.dig('did')
  end
end
