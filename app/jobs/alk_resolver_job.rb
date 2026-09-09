# frozen_string_literal: true

class AlkResolverJob < ApplicationJob
  def perform
    AlkResolver.resolve
  end
end
