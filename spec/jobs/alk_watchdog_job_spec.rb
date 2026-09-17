# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlkWatchdogJob do
  it 'calls AlkWatchdogService.call' do
    allow(AlkWatchdogService).to receive(:call)

    described_class.perform_now

    expect(AlkWatchdogService).to have_received(:call)
  end
end
