module JudgeHelpers
  def create_user(email: "learner@example.com", role: "Free")
    User.create!(email: email, password: "correct-horse-battery", role: role)
  end

  def seed_judge
    load Rails.root.join("db/seeds.rb")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "correct-horse-battery" }
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
