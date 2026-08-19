# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutletPowerProbeResolver do
  describe '.resolve' do
    let :status_json do
      {
        'status' => {
          'inputs' => [
            { 'did' => '4_P3', 'type' => 'Amps', 'name' => 'kalkStirPumpA', 'value' => 0 },
            { 'did' => '4_P11', 'type' => 'pwr', 'name' => 'kalkStirPumpW', 'value' => 0 },
            { 'did' => '4_P5', 'type' => 'Amps', 'name' => 'RO_TO_DI_6A', 'value' => 40 }
          ]
        }
      }.to_json
    end

    it 'maps the amps and watts probe dids to the given metrics' do
      result = described_class.resolve status_json, 'kalkStirPump', amps_metric: 'amps', watts_metric: 'watts'

      expect(result).to eq('4_P3' => 'amps', '4_P11' => 'watts')
    end

    it 'omits a metric whose probe is not present in the snapshot' do
      result = described_class.resolve status_json, 'unknownOutlet', amps_metric: 'amps', watts_metric: 'watts'

      expect(result).to eq({})
    end

    it 'does not raise on unparseable JSON' do
      expect { described_class.resolve('not json', 'kalkStirPump', amps_metric: 'amps', watts_metric: 'watts') }
        .not_to raise_error
    end
  end
end
