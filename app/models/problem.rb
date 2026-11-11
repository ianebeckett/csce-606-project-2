class Problem < ApplicationRecord
  SLUG_PATTERN = /\A[a-z0-9-]+\z/.freeze
  SOURCE_URL_PATTERN = %r{\Ahttps://leetcode\.com/problems/[a-z0-9-]+/\z}.freeze
  SOURCE_URL_FORMAT = "https://leetcode.com/problems/%s/".freeze
  METHOD_NAME_PATTERN = /\A[a-z_][a-z0-9_]*\z/.freeze
  EASY = "Easy".freeze
  ARGUMENTS_INPUT = "arguments".freeze
  EXACT_COMPARISON = "exact".freeze
  DIFFICULTIES = [ EASY, "Medium", "Hard" ].freeze
  INPUT_KINDS = [ ARGUMENTS_INPUT, "linked_list" ].freeze
  COMPARISONS = [ EXACT_COMPARISON, "float" ].freeze
  MINIMUM_TEST_CASES = 5
  INTERVIEW_DETAIL_RANGE = (2..4).freeze

  has_many :test_cases, -> { order(:position) }, dependent: :destroy
  has_many :practice_sessions, dependent: :restrict_with_error
  has_many :review_schedules, dependent: :restrict_with_error
  belongs_to :topic

  validates :title, :description, :starter_code, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_PATTERN }
  validates :source_url, format: { with: SOURCE_URL_PATTERN }
  validates :method_name, format: { with: METHOD_NAME_PATTERN }
  validates :difficulty, inclusion: { in: DIFFICULTIES }
  validates :input_kind, inclusion: { in: INPUT_KINDS }
  validates :comparison, inclusion: { in: COMPARISONS }
  validate :interview_details_shape, if: -> { interview_details.present? }

  def ready_for_judging?
    test_cases.size >= MINIMUM_TEST_CASES
  end

  def interview_ready?
    interview_prompt.present? && interview_details.present? && interview_twist.present?
  end

  def to_param
    slug
  end

  def starter_code_for(language)
    Judge::Language.starter_code(self, language)
  end

  private

  def interview_details_shape
    return if interview_details.is_a?(Array) && INTERVIEW_DETAIL_RANGE.cover?(interview_details.size) &&
              interview_details.all? { |detail| interview_detail?(detail) }

    errors.add(:interview_details, "must be 2 to 4 key/fact pairs")
  end

  def interview_detail?(detail)
    detail.is_a?(Hash) && detail["key"].present? && detail["fact"].present?
  end
end
