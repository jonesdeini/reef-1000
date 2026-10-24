# frozen_string_literal: true

class MeasurementsController < ApplicationController

  def index
    measurements = Measurement.all

    render json: measurements
  end

end
