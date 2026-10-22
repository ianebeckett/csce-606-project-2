class CreateJudgeTables < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "Free"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :topics do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :topics, :name, unique: true

    create_table :problems do |t|
      t.references :topic, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.string :difficulty, null: false, default: "Easy"
      t.string :source_url, null: false
      t.string :method_name, null: false
      t.string :input_kind, null: false, default: "arguments"
      t.string :comparison, null: false, default: "exact"
      t.text :starter_code, null: false
      t.timestamps
    end
    add_index :problems, :slug, unique: true

    create_table :test_cases do |t|
      t.references :problem, null: false, foreign_key: true
      t.json :input, null: false
      t.json :expected_output, null: false
      t.integer :position, null: false
      t.boolean :visible, null: false, default: false
      t.timestamps
    end
    add_index :test_cases, [ :problem_id, :position ], unique: true

    create_table :practice_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true
      t.string :status, null: false, default: "in_progress"
      t.integer :review_rating
      t.text :feedback_summary
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
    end

    create_table :attempts do |t|
      t.references :practice_session, null: false, foreign_key: true
      t.text :code, null: false
      t.string :language, null: false, default: "ruby"
      t.string :judge_result, null: false, default: "Pending"
      t.integer :passed_cases, null: false, default: 0
      t.integer :total_cases, null: false, default: 0
      t.text :error_message
      t.timestamps
    end
    add_check_constraint :attempts, "language = 'ruby'", name: "attempts_ruby_only"
    add_check_constraint :attempts, "passed_cases >= 0 AND total_cases >= passed_cases", name: "attempts_case_counts"
  end
end
