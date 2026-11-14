module JudgeHelpers
  def create_user(email: "learner@example.com", role: "Free")
    User.create!(email: email, password: "correct-horse-battery", role: role)
  end

  # The suite seeds the problems once before it starts (see rails_helper.rb
  # and features/support/env.rb), so this only reseeds if rows are missing.
  def seed_judge(force: false)
    return true if !force && defined?(JUDGE_PROBLEMS) && Problem.count >= JUDGE_PROBLEMS.size

    load Rails.root.join("db/seeds.rb")
    true
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "correct-horse-battery" }
  end

  # Premium members explain their approach to the coach before coding (US4),
  # so judge scenarios start after that conversation.
  def finish_coaching(user, problem)
    user.practice_sessions.for_today(problem).update!(coaching_state: "complexity") if user.premium?
  end

  def complete_prerequisites(user, topic)
    topic.prerequisites.each do |prerequisite|
      complete_prerequisites(user, prerequisite)
      prerequisite.problems.each do |problem|
        user.practice_sessions.for_today(problem).attempts.create!(
          code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby", judge_result: Attempt::ACCEPTED,
          passed_cases: problem.test_cases.count, total_cases: problem.test_cases.count)
      end
    end
  end
end
