# frozen_string_literal: true

class Trend < ApplicationRecord

  has_many :trends_measurements, dependent: :destroy
  has_many :measurements, through: :trends_measurements

  has_many :trends_decisions, dependent: :destroy
  has_many :decisions, through: :trends_decisions

  scope :last3, -> { order(:created_at).last 3 }

  def rising?
    apex_config = Rails.application.config.x.apex
    slope > apex_config.alk_slope_threshold && r_squared > apex_config.alk_r_squared_threshold
  end

end
