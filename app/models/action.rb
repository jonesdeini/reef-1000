# frozen_string_literal: true

class Action < ApplicationRecord
  belongs_to :resolved_reading

  validates :equipment, presence: true
end
