class ConversationMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :attempt

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
