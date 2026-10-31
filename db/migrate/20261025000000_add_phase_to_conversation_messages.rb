class AddPhaseToConversationMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :conversation_messages, :phase, :string, null: false, default: "coaching"
  end
end
