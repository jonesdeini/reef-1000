# frozen_string_literal: true

class AlkWatchdogService

  LOOKBACK = 12.hours

  def self.call
    new.call
  end

  def initialize
    @decision = Decision.new
    @actions = []
  end

  def call
    return no_op 'insufficient_measurements' if measurements.size < 2
    return no_op 'stale_data' if stale?

    attributes = LeastSquaresRegression.call(ordered_points:)
    Trend.create!(measurements:, **attributes)
    trends = Trend.last3

    actions << { 'kalk_pump' => 'off' } if SusCalculator.sus?(trends:)

    decision.update! actions:, trends:
  end

  private

  attr_reader :actions, :decision

  def no_op(undecidable_reason)
    decision.update! actions:, undecidable_reason:
  end

  def stale?
    measurements.last.recorded_at < Rails.application.config.x.apex.alk_staleness_threshold.ago
  end

  def measurements
    @measurements ||= Measurement.plausible_alk.where(recorded_at: LOOKBACK.ago..Time.current).order(:recorded_at).to_a
  end

  def ordered_points
    @ordered_points ||= measurements.pluck(:recorded_at, :value).transpose
  end

end
