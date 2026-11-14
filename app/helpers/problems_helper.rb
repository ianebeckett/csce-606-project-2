module ProblemsHelper
  # Shows a test case's arguments LeetCode-style, e.g. "nums = [1,2,3,1], k = 4".
  # Arguments are stored as a positional list, so print each one on its own
  # rather than the list itself.
  def example_input(problem, test_case)
    names = problem.parameter_names
    test_case.input.fetch("args").each_with_index.map do |value, index|
      "#{names[index] || "arg#{index + 1}"} = #{JSON.generate(value)}"
    end.join(", ")
  end
end
