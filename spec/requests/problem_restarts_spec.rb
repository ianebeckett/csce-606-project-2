require "rails_helper"

RSpec.describe "Start over", type: :request do
  before { seed_judge }

  let(:premium) { create_user(email: "premium@example.com", role: "Premium") }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  def practice(user) = user.practice_sessions.for_today(problem)

  it "asks signed-out visitors to sign in" do
    post problem_restart_path(problem)

    expect(response).to redirect_to(new_session_path)
  end

  it "clears the coach conversation and returns to the first stage" do
    sign_in(premium)
    practice(premium).update!(coaching_state: "complexity")
    practice(premium).conversation_messages.create!(role: "user", content: "Use a hash set.")
    practice(premium).conversation_messages.create!(role: "assistant", content: "Correct.")

    post problem_restart_path(problem)

    expect(response).to redirect_to(problem_path(problem, fresh: 1))
    expect(practice(premium).reload.coaching_state).to eq("problem")
    expect(practice(premium).conversation_messages).to be_empty
    follow_redirect!
    expect(response.body).to include("Starting over", "Step 1 of 3")
    expect(response.body).not_to include("Use a hash set.")
  end

  it "keeps past submissions and their code reviews but resets the editor" do
    user = create_user
    sign_in(user)
    attempt = practice(user).attempts.create!(code: "def contains_duplicate(nums)\n  my_old_code\nend\n", total_cases: 6)
    practice(user).conversation_messages.create!(attempt: attempt, role: "assistant", phase: "code_review", content: "{}")

    get problem_path(problem)
    expect(response.body).to include("my_old_code", "Start over")

    post problem_restart_path(problem)
    follow_redirect!

    expect(response.body).not_to include("my_old_code")
    expect(user.attempts.count).to eq(1)
    expect(practice(user).conversation_messages.count).to eq(1)
  end

  it "leaves another member's conversation alone" do
    other = create_user(email: "other@example.com", role: "Premium")
    practice(other).conversation_messages.create!(role: "user", content: "Mine.")
    sign_in(premium)

    post problem_restart_path(problem)

    expect(practice(other).conversation_messages.count).to eq(1)
  end

  it "does not restart a problem in a locked topic" do
    sign_in(premium)

    post problem_restart_path(Problem.find_by!(slug: "valid-palindrome"))

    expect(response).to have_http_status(:forbidden)
  end
end
