# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IntervalLogService do
  describe '.log' do
    let(:cookies) { [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')] }
    let :log_json do
      [{ 'date' => '2026-08-18T13:20:00.000Z', 'inputs' => [{ 'did' => 'base_pH', 'value' => 7.87 }] }].to_json
    end
    let(:log_url) { "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}/ilog" }

    before do
      allow(FusionAuthenticator).to receive(:authenticate).and_return cookies
    end

    context 'with the default window' do
      before { stub_request(:get, "#{log_url}?days=7").to_return status: 200, body: log_json }

      it 'authenticates first' do
        described_class.log

        expect(FusionAuthenticator).to have_received(:authenticate)
      end

      it 'returns the interval log JSON' do
        expect(described_class.log).to eq(log_json)
      end
    end

    it 'requests a custom window when days is given' do
      stub_request(:get, "#{log_url}?days=1").to_return status: 200, body: log_json

      expect(described_class.log(days: 1)).to eq(log_json)
    end
  end
end
