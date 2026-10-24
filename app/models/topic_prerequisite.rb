class TopicPrerequisite < ApplicationRecord
  belongs_to :topic
  belongs_to :prerequisite_topic, class_name: "Topic"

  validates :prerequisite_topic_id, uniqueness: { scope: :topic_id }
  validate :does_not_form_cycle

  private

  def does_not_form_cycle
    return unless topic && prerequisite_topic

    pending = [ prerequisite_topic_id ]
    visited = []
    while pending.any?
      if pending.include?(topic_id)
        errors.add(:prerequisite_topic, "cannot create a cycle")
        break
      end
      visited.concat(pending)
      # On updates, the old edge is being replaced and must not affect reachability.
      pending = self.class.where(topic_id: pending).where.not(id: id).pluck(:prerequisite_topic_id) - visited
    end
  end
end
