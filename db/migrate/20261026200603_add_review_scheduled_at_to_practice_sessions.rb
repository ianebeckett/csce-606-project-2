class AddReviewScheduledAtToPracticeSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :practice_sessions, :review_scheduled_at, :datetime
  end
end
