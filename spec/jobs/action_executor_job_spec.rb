# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActionExecutorJob do
  it 'calls ActionExecutor.call' do
    allow(ActionExecutor).to receive(:call)

    described_class.perform_now

    expect(ActionExecutor).to have_received(:call)
  end
end
