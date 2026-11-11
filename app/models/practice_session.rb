class PracticeSession < ApplicationRecord
  STATUSES = %w[in_progress completed].freeze
  # The editor unlocks on reaching the complexity stage, i.e. once the coach accepts the approach.
  COACHING_STAGES = %w[problem approach complexity].freeze
  LOCKED_STAGES = %w[problem approach].freeze
  COACHING_SKIPPED = "skipped".freeze
  COACHING_STATES = [ *COACHING_STAGES, COACHING_SKIPPED ].freeze
  INTERVIEW_STAGES = %w[not_started clarifying strategy twist coding].freeze
  INTERVIEW_SKIPPED = "skipped".freeze
  INTERVIEW_STATES = [ *INTERVIEW_STAGES, INTERVIEW_SKIPPED ].freeze
  INTERVIEW_CLARIFIED_STATES = %w[strategy twist coding skipped].freeze
  INTERVIEW_TWIST_STATES = %w[twist coding skipped].freeze
  COACH_NAMES = { "senior_swe" => "Senior SWE", "senior_grug" => "Senior Grug" }.freeze

  belongs_to :user
  belongs_to :problem
  has_many :attempts, dependent: :destroy
  has_many :conversation_messages, dependent: :destroy

  before_validation { self.practice_date = started_at&.in_time_zone&.to_date }

  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates :coaching_state, inclusion: { in: COACHING_STATES }
  validates :interview_state, inclusion: { in: INTERVIEW_STATES }
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

  def interview_locked?
    !%w[coding skipped].include?(interview_state)
  end

  def interview_clarified?
    INTERVIEW_CLARIFIED_STATES.include?(interview_state)
  end

  def interview_twist_revealed?
    INTERVIEW_TWIST_STATES.include?(interview_state)
  end

  def start_interview!
    update!(interview_state: "clarifying") if interview_state == "not_started"
  end

  def advance_interview!
    with_lock do
      stage = INTERVIEW_STAGES.index(interview_state)
      next if stage.nil? || stage.zero? || stage == INTERVIEW_STAGES.size - 1

      update!(interview_state: INTERVIEW_STAGES[stage + 1])
      post_interview_twist if interview_state == "twist"
      finish_interview! if interview_state == "coding"
    end
  end

  # Used when the AI fails, so an outage never keeps a candidate from coding.
  def skip_interview!
    return unless interview_locked?

    transaction do
      update!(interview_state: INTERVIEW_SKIPPED)
      finish_interview!
    end
  end

  def coach_name
    COACH_NAMES.fetch(coach_persona)
  end

  private

  def post_interview_twist
    conversation_messages.create!(role: "assistant", phase: "interview", content: problem.interview_twist)
  end

  # The interview supersedes the coach gate, but never marks the coach as skipped.
  def finish_interview!
    update!(coaching_state: "complexity") if coaching_locked?
  end
end
