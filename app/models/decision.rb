# frozen_string_literal: true

class Decision < ApplicationRecord

  has_many :trends_decisions, dependent: :destroy
  has_many :trends, through: :trends_decisions

end
