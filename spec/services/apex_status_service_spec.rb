# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApexStatusService do
  describe '.status' do
    let(:cookies) { [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')] }
    let(:tank_status_json) { { 'status' => { 'inputs' => [{ 'type' => 'alk', 'value' => 8.5 }] } }.to_json }
    let(:status_url) { "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}" }

    before do
      allow(FusionAuthenticator).to receive(:authenticate).and_return cookies
    end

    context 'when the request succeeds' do
      before { stub_request(:get, status_url).to_return status: 200, body: tank_status_json }

      it 'authenticates first' do
        described_class.status

        expect(FusionAuthenticator).to have_received(:authenticate)
      end

      it 'returns the tank status JSON' do
        expect(described_class.status).to eq(tank_status_json)
      end
    end

    it 'returns the raw body rather than raising on an API error' do
      stub_request(:get, status_url).to_return status: 500, body: 'Server Error'

      expect(described_class.status).to eq('Server Error')
    end
  end
end
