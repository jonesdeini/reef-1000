# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AlkWatchdogService backtest against the real 2026-08-25 incident', type: :system do
  include ActiveSupport::Testing::TimeHelpers

  before do
    [
      [Time.utc(2026, 8, 25, 19, 20, 42), 7.17, 0.9637],
      [Time.utc(2026, 8, 25, 20, 3, 32), 7.09, 0.9879],
      [Time.utc(2026, 8, 25, 22, 19, 30), 7.14, 0.9925],
      [Time.utc(2026, 8, 26, 0, 36, 14), 7.36, 0.9741],
      [Time.utc(2026, 8, 26, 1, 10, 20), 7.31, 0.9933],
      [Time.utc(2026, 8, 26, 4, 19, 30), 7.29, 0.9967],
      [Time.utc(2026, 8, 26, 7, 10, 6), 7.56, 0.9629],
      [Time.utc(2026, 8, 26, 10, 19, 28), 7.56, 0.9996],
      [Time.utc(2026, 8, 26, 13, 10, 6), 7.81, 0.9673]
    ].each do |recorded_at, value, confidence|
      create :measurement, metric: Measurement::ALK, value:, confidence:, recorded_at:
    end
  end

  def call_times
    [
      Time.utc(2026, 8, 25, 22, 0, 0),
      Time.utc(2026, 8, 26, 1, 0, 0),
      Time.utc(2026, 8, 26, 4, 0, 0),
      Time.utc(2026, 8, 26, 7, 0, 0),
      Time.utc(2026, 8, 26, 10, 0, 0),
      Time.utc(2026, 8, 26, 13, 0, 0),
      Time.utc(2026, 8, 26, 16, 0, 0)
    ]
  end

  it 'commands the pump off once enough real, rising trends have accumulated' do
    call_times.each { |call_time| travel_to(call_time) { AlkWatchdogService.call } }

    expect(Decision.last.actions).to eq([{ 'kalk_pump' => 'off' }])
  end
end
