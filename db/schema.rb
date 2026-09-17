# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_16_172700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "decisions", force: :cascade do |t|
    t.jsonb "actions", default: [], null: false
    t.datetime "executed_at"
    t.string "undecidable_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["executed_at"], name: "index_decisions_on_executed_at"
  end

  create_table "measurements", force: :cascade do |t|
    t.string "metric", null: false
    t.string "probe_id", null: false
    t.decimal "value", precision: 10, scale: 4, null: false
    t.float "confidence"
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric", "recorded_at"], name: "index_measurements_on_metric_and_recorded_at"
    t.index ["probe_id", "recorded_at"], name: "index_measurements_on_probe_id_and_recorded_at", unique: true
  end

  create_table "trends", force: :cascade do |t|
    t.float "slope", null: false
    t.float "intercept", null: false
    t.float "r_squared", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trends_decisions", force: :cascade do |t|
    t.bigint "trend_id", null: false
    t.bigint "decision_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["decision_id"], name: "index_trends_decisions_on_decision_id"
    t.index ["trend_id", "decision_id"], name: "index_trends_decisions_on_trend_id_and_decision_id", unique: true
    t.index ["trend_id"], name: "index_trends_decisions_on_trend_id"
  end

  create_table "trends_measurements", force: :cascade do |t|
    t.bigint "trend_id", null: false
    t.bigint "measurement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["measurement_id"], name: "index_trends_measurements_on_measurement_id"
    t.index ["trend_id", "measurement_id"], name: "index_trends_measurements_on_trend_id_and_measurement_id", unique: true
    t.index ["trend_id"], name: "index_trends_measurements_on_trend_id"
  end

  add_foreign_key "trends_decisions", "decisions"
  add_foreign_key "trends_decisions", "trends"
  add_foreign_key "trends_measurements", "measurements"
  add_foreign_key "trends_measurements", "trends"
end
