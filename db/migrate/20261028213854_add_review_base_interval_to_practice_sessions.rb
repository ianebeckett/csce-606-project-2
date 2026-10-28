class AddReviewBaseIntervalToPracticeSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :practice_sessions, :review_base_interval_days, :integer
  end
end
