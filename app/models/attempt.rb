class Attempt < ApplicationRecord
  PENDING = "Pending".freeze
  ACCEPTED = "Accepted".freeze
  WRONG_ANSWER = "Wrong Answer".freeze
  COMPILATION_ERROR = "Compilation Error".freeze
  RUNTIME_ERROR = "Runtime Error".freeze
  TIMEOUT = "Timeout".freeze
  JUDGE_UNAVAILABLE = "Judge Unavailable".freeze
  RESULTS = [ PENDING, ACCEPTED, WRONG_ANSWER, COMPILATION_ERROR, RUNTIME_ERROR, TIMEOUT, JUDGE_UNAVAILABLE ].freeze
  LANGUAGE = "ruby".freeze
  LANGUAGES = [ LANGUAGE, "python", "go", "cpp" ].freeze
  LANGUAGE_NAMES = {
    "ruby" => "Ruby",
    "python" => "Python",
    "go" => "Go",
    "cpp" => "C++"
  }.freeze
  LANGUAGE_VERSIONS = {
    "ruby" => "Ruby 4.0.1",
    "python" => "Python 3.15.2",
    "go" => "Go 1.27.3",
    "cpp" => "C++23 (GCC 16.2.0)"
  }.freeze
  MAX_CODE_LENGTH = 65_536

  belongs_to :practice_session
  has_one :user, through: :practice_session
  has_one :problem, through: :practice_session
  has_many :conversation_messages, dependent: :destroy
  has_one :code_review_message, -> { where(phase: "code_review") }, class_name: "ConversationMessage"

  before_validation { self.code = code.to_s }

  validates :code, length: { maximum: MAX_CODE_LENGTH }
  validates :language, inclusion: { in: LANGUAGES, message: "is not supported" }
  validates :judge_result, inclusion: { in: RESULTS }
  validates :passed_cases, :total_cases, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :valid_case_counts

  class << self
    def language_name(language)
      LANGUAGE_NAMES.fetch(language)
    end

    def language_version(language)
      LANGUAGE_VERSIONS.fetch(language)
    end
  end

  private

  def valid_case_counts
    errors.add(:passed_cases, "cannot exceed total cases") if passed_cases && total_cases && passed_cases > total_cases
  end
end
