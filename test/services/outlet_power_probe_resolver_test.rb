# frozen_string_literal: true

require 'test_helper'

class OutletPowerProbeResolverTest < ActiveSupport::TestCase
  setup do
    @status_json = {
      'status' => {
        'inputs' => [
          { 'did' => '4_P3', 'type' => 'Amps', 'name' => 'kalkStirPumpA', 'value' => 0 },
          { 'did' => '4_P11', 'type' => 'pwr', 'name' => 'kalkStirPumpW', 'value' => 0 },
          { 'did' => '4_P5', 'type' => 'Amps', 'name' => 'RO_TO_DI_6A', 'value' => 40 }
        ]
      }
    }.to_json
  end

  test 'maps the amps and watts probe dids to the given metrics' do
    result = OutletPowerProbeResolver.resolve @status_json, 'kalkStirPump', amps_metric: 'amps', watts_metric: 'watts'

    assert_equal({ '4_P3' => 'amps', '4_P11' => 'watts' }, result)
  end

  test 'omits a metric whose probe is not present in the snapshot' do
    result = OutletPowerProbeResolver.resolve @status_json, 'unknownOutlet', amps_metric: 'amps',
                                                                             watts_metric: 'watts'

    assert_equal({}, result)
  end

  test 'does not raise on unparseable JSON' do
    result = OutletPowerProbeResolver.resolve 'not json', 'kalkStirPump', amps_metric: 'amps', watts_metric: 'watts'

    assert_equal({}, result)
  end
end
