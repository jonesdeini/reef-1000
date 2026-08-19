# frozen_string_literal: true

class ApexScrapeJob < ApplicationJob
  def perform
    TridentMeasurementImporter.import TridentLogService.log
    IntervalMeasurementImporter.import IntervalLogService.log
  end
end
