# frozen_string_literal: true

class CreateTrends < ActiveRecord::Migration[8.0]

  def change
    create_table :trends do |t|
      t.float :slope, null: false
      t.float :intercept, null: false
      t.float :r_squared, null: false

      t.timestamps
    end
  end

end
