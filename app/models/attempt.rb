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
  LANGUAGES = [ LANGUAGE ].freeze
  MAX_CODE_LENGTH = 65_536

  belongs_to :practice_session
  has_one :user, through: :practice_session
  has_one :problem, through: :practice_session

  before_validation { self.code = code.to_s }

  validates :code, length: { maximum: MAX_CODE_LENGTH }
  validates :language, inclusion: { in: LANGUAGES, message: "must be Ruby; only Ruby is supported" }
  validates :judge_result, inclusion: { in: RESULTS }
  validates :passed_cases, :total_cases, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :valid_case_counts

  private

  def valid_case_counts
    errors.add(:passed_cases, "cannot exceed total cases") if passed_cases && total_cases && passed_cases > total_cases
  end
end
