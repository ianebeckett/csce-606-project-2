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
end
