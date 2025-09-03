require 'rails_helper'

RSpec.describe FusionAuthenticator do
  describe '.authenticate' do
    it 'returns cookies on successful authentication' do
      stub_request(:get, "https://apexfusion.com/login")
        .to_return(
          status: 200,
          body: '<meta name="csrf-token" content="test-csrf-token">',
          headers: { 'Set-Cookie' => 'connect.sid=initial-session' }
        )

      stub_request(:post, "https://apexfusion.com/login")
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
        .to_return(
          status: 200,
          headers: { 'Set-Cookie' => 'connect.sid=authenticated-session' }
        )

      results = described_class.authenticate

      expect(results).to contain_exactly(
        an_object_having_attributes(name: 'connect.sid', value: 'initial-session'),
        an_object_having_attributes(name: 'connect.sid', value: 'authenticated-session')
      )
    end

    it 'returns an empty array on authentication failure' do
      stub_request(:get, "https://apexfusion.com/login")
        .to_return(
          status: 200,
          body: '<meta name="csrf-token" content="test-csrf-token">',
          headers: { 'Set-Cookie' => 'connect.sid=initial-session' }
        )

      stub_request(:post, "https://apexfusion.com/login")
        .to_return(status: 401)

      results = described_class.authenticate

      expect(results).to contain_exactly(
        an_object_having_attributes(name: 'connect.sid', value: 'initial-session'),
      )
    end
  end
end
