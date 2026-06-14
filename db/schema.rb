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

ActiveRecord::Schema[8.1].define(version: 2026_06_14_000508) do
  create_table "kits", force: :cascade do |t|
    t.string "brand"
    t.datetime "created_at", null: false
    t.string "full_title"
    t.string "grade"
    t.string "grade_abbr"
    t.string "image_url"
    t.string "scale"
    t.integer "scalemates_id"
    t.string "scalemates_url"
    t.string "series"
    t.string "status", default: "unbuilt", null: false
    t.string "title", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["grade_abbr"], name: "index_kits_on_grade_abbr"
    t.index ["scalemates_id"], name: "index_kits_on_scalemates_id"
    t.index ["series"], name: "index_kits_on_series"
    t.index ["status"], name: "index_kits_on_status"
  end
end
