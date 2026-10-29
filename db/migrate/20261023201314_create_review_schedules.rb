
class CreateReviewSchedules < ActiveRecord::Migration[8.1]
  def change
    # Create the table only if it doesn't already exist
    unless table_exists?(:review_schedules)
      create_table :review_schedules do |t|
        t.references :user, null: false, foreign_key: true
        t.references :problem, null: false, foreign_key: true
        t.date :next_review_date, null: false
        t.integer :interval_days, default: 1, null: false
        t.timestamps
      end
    end

    # Add US2 fields if the table came from another feature
    unless column_exists?(:review_schedules, :next_review_date)
      add_column :review_schedules, :next_review_date, :date

      # Preserve dates from existing learning-history records
      if column_exists?(:review_schedules, :scheduled_for)
        execute "UPDATE review_schedules SET next_review_date = scheduled_for"
      end
    end

    unless column_exists?(:review_schedules, :interval_days)
      add_column :review_schedules, :interval_days,
                 :integer, default: 1, null: false
    end

    unless index_exists?(:review_schedules, [ :user_id, :problem_id ], unique: true)
      add_index :review_schedules, [ :user_id, :problem_id ], unique: true
    end

    unless check_constraint_exists?(:review_schedules, name: "review_schedules_positive_interval")
      add_check_constraint :review_schedules,
                           "interval_days >= 1",
                           name: "review_schedules_positive_interval"
    end
  end
end
