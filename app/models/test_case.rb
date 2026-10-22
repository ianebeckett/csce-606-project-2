class TestCase < ApplicationRecord
  ARGUMENT_KEYS = [ "args" ].freeze
  VISIBLE_CASE_COUNT = 2

  belongs_to :problem
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :problem_id }
  validate :valid_arguments
  validate :expected_output_present

  private

  def expected_output_present
    errors.add(:expected_output, "cannot be nil") if expected_output.nil?
  end

  def valid_arguments
    unless input.is_a?(Hash) && input.keys == ARGUMENT_KEYS && input["args"].is_a?(Array)
      errors.add(:input, "must contain an args array")
    end
  end
end
