# frozen_string_literal: true

class CreateResolvedReadings < ActiveRecord::Migration[8.0]
  def change
    create_table :resolved_readings do |t|
      t.references :measurement, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
