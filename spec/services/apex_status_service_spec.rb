require 'rails_helper'

RSpec.describe ApexStatusService do
  describe '.get_status' do
    let(:cookies) { [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')] }
    let(:tank_status_json) { { 'status' => { 'inputs' => [{ 'type' => 'alk', 'value' => 8.5 }] } }.to_json }

    before do
      allow(FusionAuthenticator).to receive(:authenticate).and_return cookies
    end

    it 'authenticates and returns tank status JSON' do
      stub_request(:get, "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}")
        .to_return status: 200, body: tank_status_json

      result = described_class.get_status

      expect(FusionAuthenticator).to have_received(:authenticate)
      expect(result).to eq(tank_status_json)
    end

    it 'handles API errors gracefully' do
      stub_request(:get, "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}")
        .to_return status: 500, body: 'Server Error'

      result = described_class.get_status

      expect(result).to eq('Server Error')
    end
  end
end
