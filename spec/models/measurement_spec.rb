# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Measurement do
  def build_measurement(**overrides)
    described_class.new({
      metric: Measurement::ALK,
      probe_id: '10_0',
      value: 7.6,
      recorded_at: Time.current
    }.merge(overrides))
  end

  it 'is valid with plausible attributes' do
    expect(build_measurement).to be_valid
  end

  context 'with no attributes' do
    subject(:measurement) { described_class.new }

    it 'is invalid' do
      expect(measurement).not_to be_valid
    end

    it 'flags metric, probe_id, value, and recorded_at' do
      measurement.valid?

      expect(measurement.errors.attribute_names).to contain_exactly(:metric, :probe_id, :value, :recorded_at)
    end
  end

  context 'with a duplicate probe_id/recorded_at pair' do
    subject(:duplicate) { build_measurement recorded_at: recorded_at }

    let(:recorded_at) { Time.current }

    before { build_measurement(recorded_at: recorded_at).save! }

    it 'is invalid' do
      expect(duplicate).not_to be_valid
    end

    it 'flags probe_id' do
      duplicate.valid?

      expect(duplicate.errors[:probe_id]).to be_present
    end
  end

  it 'allows the same probe_id at a different recorded_at' do
    build_measurement(recorded_at: 1.hour.ago).save!

    expect(build_measurement(recorded_at: Time.current)).to be_valid
  end

  describe 'plausible range per metric' do
    it 'rejects an alk value outside 0..30' do
      expect(build_measurement(metric: Measurement::ALK, value: 31)).not_to be_valid
    end

    it 'rejects a negative value regardless of metric' do
      expect(build_measurement(metric: Measurement::PH, value: -1)).not_to be_valid
    end

    it 'accepts a ph value within 0..14' do
      expect(build_measurement(metric: Measurement::PH, probe_id: 'base_pH', value: 7.87)).to be_valid
    end
  end
end
