require "rails_helper"

RSpec.describe "Learning history pages", type: :request do
  before { seed_judge }

  let(:user) { create_user }

  def create_attempt(owner, problem, result: Attempt::PENDING)
    owner.practice_sessions.for_today(problem).attempts.create!(
      code: problem.starter_code,
      judge_result: result
    )
  end

  it "shows the user's totals, topic progress, and past attempts" do
    problem = Problem.first
    attempt = create_attempt(user, problem, result: Attempt::ACCEPTED)
    user.review_schedules.create!(problem: problem, scheduled_for: Date.current)
    attempt.practice_session.conversation_messages.create!(role: "assistant", content: "Nice work.")
    sign_in(user)

    get history_index_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Problems solved: 1",
      "Reviews scheduled: 1",
      ERB::Util.html_escape(problem.topic.name).to_s,
      "1 / 1 problems solved",
      problem.title,
      Attempt::ACCEPTED
    )
    expect(response.body).to include(history_path(attempt))

    get history_path(attempt)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      ERB::Util.html_escape(problem.topic.name).to_s,
      attempt.code,
      Attempt::ACCEPTED,
      "Nice work.",
      "Assistant"
    )
    expect(response.body).to include(history_index_path)
  end

  it "shows an empty state for an account without history" do
    sign_in(user)

    get history_index_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Problems solved: 0",
      "Reviews scheduled: 0",
      "No practice history yet."
    )
  end

  it "does not expose another user's attempt" do
    attempt = create_attempt(create_user(email: "other@example.com"), Problem.first)
    sign_in(user)

    get history_path(attempt)

    expect(response).to have_http_status(:not_found)
  end

  it "requires login" do
    get history_index_path

    expect(response).to redirect_to(new_session_path)
  end
end
