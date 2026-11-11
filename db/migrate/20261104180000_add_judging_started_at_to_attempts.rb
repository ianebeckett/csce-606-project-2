class AddJudgingStartedAtToAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :attempts, :judging_started_at, :datetime
    add_index :attempts, :judge_result
  end
end
