class AddInterviewToProblemsAndPracticeSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :problems, :interview_prompt, :text
    add_column :problems, :interview_details, :json
    add_column :problems, :interview_twist, :text
    add_column :practice_sessions, :interview_state, :string, null: false, default: "not_started"
  end
end
