class AddPracticeDate < ActiveRecord::Migration[8.1]
  def up
    add_column :practice_sessions, :practice_date, :date
    sessions = Class.new(ActiveRecord::Base) { self.table_name = "practice_sessions" }
    sessions.reset_column_information
    sessions.find_each do |session|
      session.update_columns(practice_date: session.started_at.in_time_zone("America/Chicago").to_date)
    end
    change_column_null :practice_sessions, :practice_date, false
    add_index :practice_sessions, [ :user_id, :problem_id, :practice_date ], unique: true,
      name: "index_practice_sessions_on_user_problem_date"
  end

  def down
    remove_index :practice_sessions, name: "index_practice_sessions_on_user_problem_date"
    remove_column :practice_sessions, :practice_date
  end
end
