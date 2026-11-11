module Judge
  class Submission
    FLOAT_TOLERANCE = 0.00001
    BLANK_CODE_MESSAGE = "Code can't be blank.".freeze
    RESULT_MESSAGES = {
      Attempt::COMPILATION_ERROR => "Your code could not be compiled.",
      Attempt::RUNTIME_ERROR => "Your code stopped during execution.",
      Attempt::TIMEOUT => "Your code exceeded the time limit.",
      Attempt::JUDGE_UNAVAILABLE => "The judge is temporarily unavailable. Please try again."
    }.freeze

    def initialize(runner: nil)
      @runner = runner || Runner.build
    end

    def call(attempt)
      cases = attempt.problem.test_cases.to_a
      attempt.assign_attributes(total_cases: cases.length, passed_cases: 0)
      unless attempt.problem.ready_for_judging?
        return save_result(attempt, Attempt::JUDGE_UNAVAILABLE, "At least five predefined cases are required.")
      end
      return save_result(attempt, Attempt::RUNTIME_ERROR, BLANK_CODE_MESSAGE) if attempt.code.blank?

      result = @runner.call(
        code: attempt.code,
        language: attempt.language,
        problem: attempt.problem,
        inputs: cases.map(&:input)
      )
      outputs = result.fetch("outputs", [])
      outputs.each_with_index do |output, index|
        test_case = cases.fetch(index)
        attempt.passed_cases += 1 if correct?(output, test_case.expected_output, attempt.problem.comparison)
      end
      status = result.fetch("status")
      return save_result(attempt, status, RESULT_MESSAGES.fetch(status)) unless status == DockerRunner::SUCCESS_STATUS
      return save_result(attempt, Attempt::RUNTIME_ERROR, RESULT_MESSAGES.fetch(Attempt::RUNTIME_ERROR)) unless outputs.length == cases.length

      verdict = attempt.passed_cases == cases.length ? Attempt::ACCEPTED : Attempt::WRONG_ANSWER
      save_result(attempt, verdict)
    rescue SystemCallError, ThreadError
      save_result(attempt, Attempt::JUDGE_UNAVAILABLE, RESULT_MESSAGES.fetch(Attempt::JUDGE_UNAVAILABLE))
    end

    private
    def save_result(attempt, verdict, message = nil)
      # Save the result of the student's coding attempt
      attempt.update!(
        judge_result: verdict,
        error_message: message
      )
      attempt
    end

    def correct?(actual, expected, comparison)
      return actual == expected if comparison == Problem::EXACT_COMPARISON

      actual.is_a?(Numeric) && actual.finite? && (actual - expected).abs < FLOAT_TOLERANCE
    end
  end
end
