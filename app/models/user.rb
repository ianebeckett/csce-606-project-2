class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12
  ROLES = %w[Free Premium].freeze

  has_secure_password
  has_many :practice_sessions, dependent: :destroy
  has_many :attempts, through: :practice_sessions

  has_many :conversation_messages, through: :practice_sessions
  has_many :review_schedules, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  def premium?
    role == "Premium"
  end

  def solved_problem_ids
    attempts.joins(:practice_session).where(judge_result: Attempt::ACCEPTED)
      .distinct.pluck("practice_sessions.problem_id")
  end

  def solved_count
    solved_problem_ids.size
  end

  def review_count
    review_schedules.count
  end

  def topic_progress
    solved_ids = solved_problem_ids

    Topic.includes(:problems).order(:position, :id).map do |topic|
      problem_ids = topic.problems.map(&:id)
      {
        topic: topic,
        solved_count: problem_ids.count { |problem_id| solved_ids.include?(problem_id) },
        total_count: problem_ids.size
      }
    end
  end
end
