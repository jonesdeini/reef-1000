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

ActiveRecord::Schema[8.0].define(version: 2026_08_19_013302) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
end
