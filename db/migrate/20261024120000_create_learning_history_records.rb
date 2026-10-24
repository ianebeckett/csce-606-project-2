class CreateLearningHistoryRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_messages do |t|
      t.references :attempt, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.timestamps
    end

    create_table :review_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true
      t.date :scheduled_for, null: false
      t.datetime :reviewed_at
      t.timestamps
    end
  end
end
