
class CreateLearningHistoryRecords < ActiveRecord::Migration[8.1]
  def change
    if table_exists?(:review_schedules)
      add_column :review_schedules, :scheduled_for, :date unless column_exists?(:review_schedules, :scheduled_for)
      add_column :review_schedules, :reviewed_at, :datetime unless column_exists?(:review_schedules, :reviewed_at)
    else
      create_table :review_schedules do |t|
        t.references :user, null: false, foreign_key: true
        t.references :problem, null: false, foreign_key: true
        t.date :scheduled_for, null: false
        t.datetime :reviewed_at
        t.timestamps
      end
    end
  end
end
