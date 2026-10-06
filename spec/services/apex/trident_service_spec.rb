# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Apex::TridentService do
  let(:cookies) { [HTTP::Cookie.new('connect.sid', 'test-session', domain: 'apexfusion.com')] }
  let(:base_path) { "https://apexfusion.com/api/apex/#{Rails.application.config.x.apex.controller_id}" }
  let(:body) { '{"did":"10_4","gid":"","name":"Alk_10_4","type":"selector","ID":43,"status":["ON","","OK",""]}' }

  before do
    allow(FusionAuthenticator).to receive(:authenticate).and_return cookies
  end

  describe '#trigger_alk_test!' do
    it 'sends a PUT request to the base path with the correct payload' do
      stub = stub_request(:put, base_path).with(body:).to_return status: 200, body: {}.to_json

      described_class.trigger_alk_test!

      expect(stub).to have_been_requested
    end
  end
end
