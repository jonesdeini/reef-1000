# frozen_string_literal: true

class CreateTrendsDecisions < ActiveRecord::Migration[8.0]

  def change
    create_table :trends_decisions do |t|
      t.references :trend, null: false, foreign_key: true
      t.references :decision, null: false, foreign_key: true
      t.index %i[trend_id decision_id], unique: true

      t.timestamps
    end
  end

end
