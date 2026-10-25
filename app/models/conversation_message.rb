class ConversationMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :practice_session
  belongs_to :attempt, optional: true

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
  validate :attempt_in_same_session

  scope :chronological, -> { order(:created_at, :id) }

  private

  def attempt_in_same_session
    return if attempt.nil? || attempt.practice_session_id == practice_session_id

    errors.add(:attempt, "must belong to the same practice session")
  end
end
