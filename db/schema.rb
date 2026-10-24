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

ActiveRecord::Schema[8.1].define(version: 2026_10_23_201314) do
  create_table "attempts", force: :cascade do |t|
    t.integer "practice_session_id", null: false
    t.text "code", null: false
    t.string "language", default: "ruby", null: false
    t.string "judge_result", default: "Pending", null: false
    t.integer "passed_cases", default: 0, null: false
    t.integer "total_cases", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["practice_session_id"], name: "index_attempts_on_practice_session_id"
    t.check_constraint "language = 'ruby'", name: "attempts_ruby_only"
    t.check_constraint "passed_cases >= 0 AND total_cases >= passed_cases", name: "attempts_case_counts"
  end

  create_table "practice_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "problem_id", null: false
    t.string "status", default: "in_progress", null: false
    t.integer "review_rating"
    t.text "feedback_summary"
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "practice_date", null: false
    t.index ["problem_id"], name: "index_practice_sessions_on_problem_id"
    t.index ["user_id", "problem_id", "practice_date"], name: "index_practice_sessions_on_user_problem_date", unique: true
    t.index ["user_id"], name: "index_practice_sessions_on_user_id"
  end

  create_table "problems", force: :cascade do |t|
    t.integer "topic_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.string "difficulty", default: "Easy", null: false
    t.string "source_url", null: false
    t.string "method_name", null: false
    t.string "input_kind", default: "arguments", null: false
    t.string "comparison", default: "exact", null: false
    t.text "starter_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_problems_on_slug", unique: true
    t.index ["topic_id"], name: "index_problems_on_topic_id"
  end

  create_table "review_schedules", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "problem_id", null: false
    t.date "next_review_date", null: false
    t.integer "interval_days", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id"], name: "index_review_schedules_on_problem_id"
    t.index ["user_id", "problem_id"], name: "index_review_schedules_on_user_id_and_problem_id", unique: true
    t.index ["user_id"], name: "index_review_schedules_on_user_id"
    t.check_constraint "interval_days >= 1", name: "review_schedules_positive_interval"
  end

  create_table "test_cases", force: :cascade do |t|
    t.integer "problem_id", null: false
    t.json "input", null: false
    t.json "expected_output", null: false
    t.integer "position", null: false
    t.boolean "visible", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id", "position"], name: "index_test_cases_on_problem_id_and_position", unique: true
    t.index ["problem_id"], name: "index_test_cases_on_problem_id"
  end

  create_table "topic_prerequisites", force: :cascade do |t|
    t.integer "topic_id", null: false
    t.integer "prerequisite_topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prerequisite_topic_id"], name: "index_topic_prerequisites_on_prerequisite_topic_id"
    t.index ["topic_id", "prerequisite_topic_id"], name: "idx_on_topic_id_prerequisite_topic_id_1515a7b7d6", unique: true
    t.index ["topic_id"], name: "index_topic_prerequisites_on_topic_id"
    t.check_constraint "topic_id != prerequisite_topic_id", name: "topics_cannot_require_themselves"
  end

  create_table "topics", force: :cascade do |t|
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_topics_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "Free", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "attempts", "practice_sessions"
  add_foreign_key "practice_sessions", "problems"
  add_foreign_key "practice_sessions", "users"
  add_foreign_key "problems", "topics"
  add_foreign_key "review_schedules", "problems"
  add_foreign_key "review_schedules", "users"
  add_foreign_key "test_cases", "problems"
  add_foreign_key "topic_prerequisites", "topics"
  add_foreign_key "topic_prerequisites", "topics", column: "prerequisite_topic_id"
end
