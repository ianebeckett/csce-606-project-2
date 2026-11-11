module Judge
  class Payload
    class << self
      def build(code:, language:, problem:, inputs:)
        {
          code: code,
          language: language,
          runtime: Attempt.language_version(language),
          method_name: problem.method_name,
          input_kind: problem.input_kind,
          inputs: inputs,
          output_kind: output_kind(problem)
        }
      end

      private

      def output_kind(problem)
        return "linked_list" if problem.input_kind == "linked_list"

        output = problem.test_cases.first.expected_output
        return "boolean" if output == true || output == false
        return "number" if output.is_a?(Numeric)

        "value"
      end
    end
  end
end
