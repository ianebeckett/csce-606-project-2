class CreateTopicPrerequisites < ActiveRecord::Migration[8.1]
  def change
    create_table :topic_prerequisites do |t|
      t.references :topic, null: false, foreign_key: true
      t.references :prerequisite_topic, null: false, foreign_key: { to_table: :topics }
      t.timestamps
    end
    add_index :topic_prerequisites, [ :topic_id, :prerequisite_topic_id ], unique: true
    add_check_constraint :topic_prerequisites, "topic_id != prerequisite_topic_id", name: "topics_cannot_require_themselves"
  end
end
