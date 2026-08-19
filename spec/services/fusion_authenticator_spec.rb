# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FusionAuthenticator do
  describe '.authenticate' do
    before do
      stub_request(:get, 'https://apexfusion.com/login').to_return(
        status: 200,
        body: '<meta name="csrf-token" content="test-csrf-token">',
        headers: { 'Set-Cookie' => 'connect.sid=initial-session' }
      )
    end

    context 'when login succeeds' do
      before do
        stub_request(:post, 'https://apexfusion.com/login')
          .with(
            headers: {
              'X-CSRF-Token' => 'test-csrf-token',
              'Cookie' => 'connect.sid=initial-session'
            },
            body: {
              username: Rails.application.config.x.apex.fusion_username,
              password: Rails.application.config.x.apex.fusion_password,
              remember_me: 'false'
            }
          )
          .to_return(status: 200, headers: { 'Set-Cookie' => 'connect.sid=authenticated-session' })
      end

      it 'returns cookies from both the login page and the authenticated session' do
        expect(described_class.authenticate).to contain_exactly(
          an_object_having_attributes(name: 'connect.sid', value: 'initial-session'),
          an_object_having_attributes(name: 'connect.sid', value: 'authenticated-session')
        )
      end
    end

    context 'when login fails' do
      before { stub_request(:post, 'https://apexfusion.com/login').to_return status: 401 }

      it 'returns only the cookie from the login page' do
        expect(described_class.authenticate).to contain_exactly(
          an_object_having_attributes(name: 'connect.sid', value: 'initial-session')
        )
      end
    end
  end
end
