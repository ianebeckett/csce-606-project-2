class PracticeSession < ApplicationRecord
  STATUSES = %w[in_progress completed].freeze

  belongs_to :user
  belongs_to :problem
  has_many :attempts, dependent: :destroy
  has_many :conversation_messages, dependent: :destroy

  before_validation { self.practice_date = started_at&.in_time_zone&.to_date }

  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  def self.for_today(problem)
    now = Time.current
    find_or_create_by!(problem: problem, practice_date: now.to_date) { |session| session.started_at = now }
  end
end
