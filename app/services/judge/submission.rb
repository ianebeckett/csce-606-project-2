module Judge
  class Submission
    ERROR_MESSAGE_LIMIT = 1000
    FLOAT_TOLERANCE = 0.00001

    def initialize(runner: DockerRunner.new)
      @runner = runner
    end

    def call(attempt)
      cases = attempt.problem.test_cases.to_a
      attempt.assign_attributes(total_cases: cases.length, passed_cases: 0)
      unless attempt.problem.ready_for_judging?
        return save_result(attempt, Attempt::JUDGE_UNAVAILABLE, "At least five predefined cases are required.")
      end

      cases.each do |test_case|
        result = @runner.call(code: attempt.code, problem: attempt.problem, input: test_case.input)
        unless result.fetch("status") == DockerRunner::SUCCESS_STATUS
          return save_result(attempt, result.fetch("status"), result["message"].to_s.first(ERROR_MESSAGE_LIMIT))
        end
        attempt.passed_cases += 1 if correct?(result["output"], test_case.expected_output, attempt.problem.comparison)
      end
      verdict = attempt.passed_cases == cases.length ? Attempt::ACCEPTED : Attempt::WRONG_ANSWER
      save_result(attempt, verdict)
    rescue SystemCallError, ThreadError
      save_result(attempt, Attempt::JUDGE_UNAVAILABLE, DockerRunner::UNAVAILABLE_MESSAGE)
    end

    private

    def save_result(attempt, verdict, message = nil)
      attempt.update!(judge_result: verdict, error_message: message)
      attempt
    end

    def correct?(actual, expected, comparison)
      return actual == expected if comparison == Problem::EXACT_COMPARISON

      actual.is_a?(Numeric) && actual.finite? && (actual - expected).abs < FLOAT_TOLERANCE
    end
  end
end
