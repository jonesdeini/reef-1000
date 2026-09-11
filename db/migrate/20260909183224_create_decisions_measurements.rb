# frozen_string_literal: true

class CreateDecisionsMeasurements < ActiveRecord::Migration[8.0]

  def change
    create_table :decisions_measurements do |t|
      t.references :decision, null: false, foreign_key: true
      t.references :measurement, null: false, foreign_key: true
      t.index %i[decision_id measurement_id], unique: true

      t.timestamps
    end
  end

end
