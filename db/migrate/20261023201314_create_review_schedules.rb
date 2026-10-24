class CreateReviewSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :review_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true

      # Date when the student should review this problem again
      t.date :next_review_date, null: false

      # Number of days between reviews
      t.integer :interval_days, default: 1, null: false

      t.timestamps
    end

    # A student can only have one review schedule per problem
    add_index :review_schedules, [:user_id, :problem_id], unique: true

    # Review intervals must be at least one day
    add_check_constraint :review_schedules,
                         "interval_days >= 1",
                         name: "review_schedules_positive_interval"
  end
end