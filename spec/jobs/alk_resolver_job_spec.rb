# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlkResolverJob do
  it 'calls AlkResolver.resolve' do
    allow(AlkResolver).to receive(:resolve)

    described_class.perform_now

    expect(AlkResolver).to have_received(:resolve)
  end
end
