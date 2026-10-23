class Topic < ApplicationRecord
  has_many :problems, dependent: :restrict_with_error
  has_many :topic_prerequisites, dependent: :destroy
  has_many :prerequisites, through: :topic_prerequisites, source: :prerequisite_topic
  has_many :dependent_prerequisites, class_name: "TopicPrerequisite", foreign_key: :prerequisite_topic_id, dependent: :destroy
  validates :name, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
[]
