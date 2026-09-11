# frozen_string_literal: true

class AlkWatchdogService

  TARGET_DKH = 8.0
  DEADBAND = 0.4

  STALENESS_WINDOW = 6.hours
  CONFIDENCE_FLOOR = 0.9

  LOOKBACK = 12.hours

  def self.call
    new.call
  end

  def call
    SusCalculator.call alk_readings
    decision = Decision.create! action: action
    decision.measurements = measurements
    decision
  end

  private

  def alk_readings
    @alk_readings ||= Measurement.alk.where(recorded_at: LOOKBACK.ago..).order(:recorded_at).to_a
  end

  def action
    latest = alk_readings.last
    return none_action if latest.nil?
    return none_action unless fresh?(latest) && confident?(latest)

    latest.value.to_f > TARGET_DKH + DEADBAND ? { 'pump' => 'off' } : none_action
  end

  def none_action
    { 'pump' => 'none' }
  end

  def fresh?(reading)
    reading.recorded_at >= STALENESS_WINDOW.ago
  end

  def confident?(reading)
    reading.confidence && reading.confidence >= CONFIDENCE_FLOOR
  end

end
