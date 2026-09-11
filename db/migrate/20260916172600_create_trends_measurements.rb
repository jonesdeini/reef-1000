# frozen_string_literal: true

class CreateTrendsMeasurements < ActiveRecord::Migration[8.0]

  def change
    create_table :trends_measurements do |t|
      t.references :trend, null: false, foreign_key: true
      t.references :measurement, null: false, foreign_key: true
      t.index %i[trend_id measurement_id], unique: true

      t.timestamps
    end
  end

end
