# frozen_string_literal: true

FactoryBot.define do
  factory :decision do
    action { { 'pump' => 'off' } }
  end
end
