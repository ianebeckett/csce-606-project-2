class PracticeSession < ApplicationRecord
  STATUSES = %w[in_progress completed].freeze
  # The editor unlocks on reaching the complexity stage, i.e. once the coach accepts the approach.
  COACHING_STAGES = %w[problem approach complexity].freeze
  LOCKED_STAGES = %w[problem approach].freeze
  COACHING_SKIPPED = "skipped".freeze
  COACHING_STATES = [ *COACHING_STAGES, COACHING_SKIPPED ].freeze
  COACH_NAMES = { "senior_swe" => "Senior SWE", "senior_grug" => "Senior Grug" }.freeze

  belongs_to :user
  belongs_to :problem
  has_many :attempts, dependent: :destroy
  has_many :conversation_messages, dependent: :destroy

  before_validation { self.practice_date = started_at&.in_time_zone&.to_date }

  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates :coaching_state, inclusion: { in: COACHING_STATES }
  validates :coach_persona, inclusion: { in: COACH_NAMES.keys }

  def self.for_today(problem)
    now = Time.current
    find_or_create_by!(problem: problem, practice_date: now.to_date) { |session| session.started_at = now }
  end

  def coaching_locked?
    LOCKED_STAGES.include?(coaching_state)
  end

  def advance_coaching!
    stage = COACHING_STAGES.index(coaching_state)
    return if stage.nil? || stage == COACHING_STAGES.size - 1

    update!(coaching_state: COACHING_STAGES[stage + 1])
  end

  # Used when the AI fails, so an outage never keeps a candidate from coding.
  def skip_coaching!
    update!(coaching_state: COACHING_SKIPPED) if coaching_locked?
  end

  def coach_name
    COACH_NAMES.fetch(coach_persona)
  end
end
