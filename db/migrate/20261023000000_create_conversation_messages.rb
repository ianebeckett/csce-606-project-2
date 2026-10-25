class CreateConversationMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :practice_sessions, :coaching_state, :string, null: false, default: "problem"
    add_column :practice_sessions, :coach_persona, :string, null: false, default: "senior_swe"
    create_table :conversation_messages do |t|
      t.references :practice_session, null: false, foreign_key: true
      t.references :attempt, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.timestamps
    end
  end
end
