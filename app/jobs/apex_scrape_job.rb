# frozen_string_literal: true

class ApexScrapeJob < ApplicationJob
  def perform
    TridentMeasurementImporter.import TridentLogService.log
    IntervalMeasurementImporter.import IntervalLogService.log, extra_probe_metrics: kalk_pump_probe_metrics
  end

  private

  def kalk_pump_probe_metrics
    OutletPowerProbeResolver.resolve(
      ApexStatusService.status,
      Rails.application.config.x.apex.kalk_pump_output_name,
      amps_metric: Measurement::KALK_PUMP_AMPS,
      watts_metric: Measurement::KALK_PUMP_WATTS
    )
  end
end
