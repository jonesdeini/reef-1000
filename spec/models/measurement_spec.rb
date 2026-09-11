# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Measurement do
  include ActiveSupport::Testing::TimeHelpers

  context 'with no attributes' do
    it 'is invalid' do
      measurement = described_class.new

      expect(measurement).not_to be_valid
    end

    it 'flags metric, probe_id, value, and recorded_at' do
      measurement = described_class.new
      measurement.valid?

      expect(measurement.errors.attribute_names).to contain_exactly(:metric, :probe_id, :value, :recorded_at)
    end
  end

  context 'with a duplicate probe_id/recorded_at pair' do
    subject(:duplicate) { build(:measurement, probe_id:, recorded_at:) }

    around { |example| freeze_time { example.run } }

    let(:probe_id) { 'ph' }
    let(:recorded_at) { Time.current }

    before { create(:measurement, probe_id:, recorded_at:) }

    it 'is invalid' do
      expect(duplicate).not_to be_valid
    end

    it 'flags probe_id' do
      duplicate.valid?

      expect(duplicate.errors[:probe_id]).to eq ['has already been taken']
    end
  end

  it 'allows the same probe_id at a different recorded_at' do
    probe_id = 'ph'
    create(:measurement, probe_id:)
    non_duplicate = build :measurement, probe_id:, recorded_at: 1.hour.ago

    expect(non_duplicate).to be_valid
  end
end
