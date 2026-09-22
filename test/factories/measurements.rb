# frozen_string_literal: true

FactoryBot.define do
  factory :measurement do
    metric { 'alk' }
    probe_id { 'trident' }
    value { 8.02 }
    recorded_at { Time.current }
  end
end
