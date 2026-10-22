module CodeReviewHelpers
  REVIEWED_CODE = "def contains_duplicate(nums)\n  nums.each_with_index.any? { |n, i| nums[i + 1..].include?(n) }\nend\n".freeze

  def create_attempt(user, code: REVIEWED_CODE, slug: "contains-duplicate")
    problem = Problem.find_by!(slug: slug)
    user.practice_sessions.create!(problem: problem, started_at: Time.current).attempts.create!(
      code: code, language: "ruby", judge_result: "Accepted", passed_cases: 6, total_cases: 6)
  end

  def ai_review_reply(suggestions: [])
    {
      summary: "Correct, but the nested scan is quadratic.",
      complexity: { time: "O(n^2)", space: "O(1)" },
      suggestions: suggestions
    }.to_json
  end

  def use_ai_client(client)
    Rails.configuration.x.ai_client = client
  end
end
