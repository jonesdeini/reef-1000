# frozen_string_literal: true

class CreateMeasurements < ActiveRecord::Migration[8.0]
  def change
    create_table :measurements do |t|
      t.string :metric, null: false
      t.string :probe_id, null: false
      t.decimal :value, null: false, precision: 10, scale: 4
      t.float :confidence
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :measurements, %i[probe_id recorded_at], unique: true
    add_index :measurements, %i[metric recorded_at]
  end
end
