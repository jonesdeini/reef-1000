# frozen_string_literal: true

class AlkResolver
  TARGET_DKH = 8.0
  DEADBAND = 0.4

  # TODO: not data-grounded like TARGET_DKH/DEADBAND above - a generous
  # placeholder spanning the Trident's ~3h irregular test cadence.
  STALENESS_WINDOW = 6.hours
  # TODO: not data-grounded - a placeholder near the low end of the
  # observed ~0.94-0.99 confidence range.
  CONFIDENCE_FLOOR = 0.9

  TREND_WINDOW = 3

  def self.analyze(readings:, pump_running_recently:)
    new(readings: readings, pump_running_recently: pump_running_recently).analyze
  end

  def self.resolve
    latest = Measurement.alk.order(:recorded_at).last
    return if latest.nil? || ResolvedReading.exists?(measurement_id: latest.id)

    persist_resolution latest
  end

  def self.persist_resolution(latest)
    readings = trend_readings latest
    result = analyze readings: readings, pump_running_recently: pump_running_recently_for(readings)

    resolved_reading = ResolvedReading.create! measurement: latest, metadata: result[:metadata]
    result[:actions].each { |spec| resolved_reading.actions.create! spec }
    resolved_reading
  end
  private_class_method :persist_resolution

  def self.trend_readings(latest)
    Measurement.alk.where(recorded_at: ..latest.recorded_at).order(:recorded_at).last TREND_WINDOW
  end
  private_class_method :trend_readings

  def self.pump_running_recently_for(readings)
    Measurement.where(metric: Measurement::KALK_PUMP_WATTS)
               .where(recorded_at: readings.first.recorded_at..readings.last.recorded_at)
               .where('value > 0')
               .exists?
  end
  private_class_method :pump_running_recently_for

  def initialize(readings:, pump_running_recently:)
    @readings = readings
    @pump_running_recently = pump_running_recently
  end

  def analyze
    current = readings.last
    metadata = base_metadata current

    return { metadata: metadata, actions: [] } unless metadata['fresh'] && metadata['confident']

    metadata.merge! trend_metadata
    band_result current, metadata
  end

  private

  attr_reader :readings, :pump_running_recently

  def base_metadata(current)
    {
      'fresh' => fresh?(current),
      'confident' => confident?(current),
      'pump_running_recently' => pump_running_recently
    }
  end

  def band_result(current, metadata)
    value = current.value.to_f
    if value > TARGET_DKH + DEADBAND
      metadata['above_band'] = true
      return { metadata: metadata, actions: [above_band_action] }
    end

    metadata['below_band'] = true if value < TARGET_DKH - DEADBAND
    { metadata: metadata, actions: [] }
  end

  def fresh?(reading)
    reading.recorded_at >= STALENESS_WINDOW.ago
  end

  def confident?(reading)
    return false if reading.confidence.nil?

    reading.confidence >= CONFIDENCE_FLOOR
  end

  def trend_metadata
    return {} if readings.size < 2

    delta = (readings.last.value - readings.first.value).to_f.round 4
    direction = if delta.positive?
                  'up'
                elsif delta.negative?
                  'down'
                else
                  'flat'
                end

    { 'trend_direction' => direction, 'trend_magnitude' => delta.abs }
  end

  def above_band_action
    { equipment: 'kalk_pump', payload: { 'command' => 'off', 'reason' => 'above_band' } }
  end
end
