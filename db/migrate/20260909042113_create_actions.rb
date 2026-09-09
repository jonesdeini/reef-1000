# frozen_string_literal: true

class CreateActions < ActiveRecord::Migration[8.0]
  def change
    create_table :actions do |t|
      t.references :resolved_reading, null: false, foreign_key: true
      t.string :equipment, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :executed_at

      t.timestamps
    end

    add_index :actions, :equipment
  end
end
