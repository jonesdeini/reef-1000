# frozen_string_literal: true

class ApexScrapeJob < ApplicationJob
  def perform
    MeasurementImporter.import_trident_log TridentLogService.log
    MeasurementImporter.import_status ApexStatusService.status
  end
end
