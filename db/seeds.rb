require_relative "judge_problems"

ActiveRecord::Base.transaction do
  JUDGE_PROBLEMS.each_with_index do |definition, index|
    topic = Topic.find_or_initialize_by(name: definition.fetch(:topic))
    topic.update!(position: index)
    problem = Problem.find_or_initialize_by(slug: definition.fetch(:slug))
    problem.update!(
      topic: topic, title: definition.fetch(:title), description: definition.fetch(:description),
      difficulty: Problem::EASY, source_url: format(Problem::SOURCE_URL_FORMAT, definition.fetch(:slug)),
      method_name: definition.fetch(:method_name), input_kind: definition.fetch(:input_kind, Problem::ARGUMENTS_INPUT),
      comparison: definition.fetch(:comparison, Problem::EXACT_COMPARISON),
      starter_code: "def #{definition.fetch(:method_name)}(#{definition.fetch(:arguments)})\nend\n"
    )
    definition.fetch(:cases).each_with_index do |(arguments, output), position|
      test_case = problem.test_cases.find_or_initialize_by(position: position)
      test_case.update!(input: { args: arguments }, expected_output: output, visible: position < TestCase::VISIBLE_CASE_COUNT)
    end
  end
end
