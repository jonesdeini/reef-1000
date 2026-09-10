# frozen_string_literal: true

class CreateDecisions < ActiveRecord::Migration[8.0]

  def change
    create_table :decisions do |t|
      t.jsonb :action, null: false, default: {}
      t.datetime :executed_at

      t.timestamps
    end

    add_index :decisions, :executed_at
  end

end
