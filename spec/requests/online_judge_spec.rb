require "rails_helper"

RSpec.describe "Online Judge requests", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { seed_judge }
  let(:user) { create_user }

  it "registers only Free members and does not accept a role supplied by the browser" do
    post registration_path, params: { user: { email: "new@example.com", password: "correct-horse-battery", password_confirmation: "correct-horse-battery", role: "Premium" } }
    expect(User.find_by!(email: "new@example.com").role).to eq("Free")
    expect(response).to redirect_to(problems_path)
  end

  it "rejects an invalid registration" do
    post registration_path, params: { user: { email: "bad", password: "short" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "authenticates, filters topics, and signs out without JavaScript" do
    get new_session_path
    expect(response.body).to include("<h1>Sign in</h1>")
    get new_registration_path
    expect(response.body).to include("Create account")
    sign_in(user)
    get problems_path(topic: Topic.find_by!(name: "Stack").id)
    expect(response.body).to include("<h1>Problems</h1>")
    expect(response.body).to include("Valid Parentheses")
    expect(response.body).not_to include('>Contains Duplicate</a>')
    delete session_path
    get attempts_path
    expect(response).to redirect_to(new_session_path)
    expect do
      post problem_attempts_path(Problem.first), params: { attempt: { code: "puts 1", language: "ruby" } }
    end.not_to change(Attempt, :count)
    expect(response).to redirect_to(new_session_path)
  end

  it "scopes saved attempts and history to the current user" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")
    session = user.practice_sessions.create!(problem: problem, started_at: Time.current)
    attempt = session.attempts.create!(code: "private Ruby source", language: "ruby")
    get attempt_path(attempt)
    expect(response.body).to include("test cases passed")
    get attempts_path
    expect(response.body).to include(problem.title)
    delete session_path
    sign_in(create_user(email: "second@example.com"))
    get attempt_path(attempt)
    expect(response).to have_http_status(:not_found)
  end

  it "groups retries by day and restores the user's latest code across sessions" do
    sign_in(user)
    problem = Problem.first
    code = "def contains_duplicate(nums)\n"
    travel_to(Time.utc(2026, 10, 21, 4, 59, 59)) do
      expect { get problem_path(problem) }.not_to change(PracticeSession, :count)
      expect do
        2.times { post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } } }
      end.to change(PracticeSession, :count).by(1).and change(Attempt, :count).by(2)
      yesterday = user.practice_sessions.sole
      travel 1.second
      expect do
        post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } }
      end.to change(PracticeSession, :count).by(1).and change(Attempt, :count).by(1)
      expect(yesterday.attempts.count).to eq(2)
      expect(user.attempts.order(:id).last.practice_session).not_to eq(yesterday)
    end
    get problem_path(problem)
    expect(response.body).to include("def contains_duplicate(nums)")
    expect(response.body).not_to include(problem.starter_code)
  end

  it "saves Judge Unavailable when the judge process cannot start" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")
    command = instance_double(Judge::Command)
    allow(command).to receive(:call).and_raise(Errno::EACCES, "docker")
    allow(Judge::Command).to receive(:new).and_return(command)

    expect do
      post problem_attempts_path(problem), params: {
        attempt: { code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby" }
      }
    end.to change(Attempt, :count).by(1)

    attempt = Attempt.order(:id).last
    expect(response).to redirect_to(attempt_path(attempt))
    expect(attempt.reload.judge_result).to eq("Judge Unavailable")
    expect(attempt.error_message).to eq("The Ruby judge is unavailable. Your code was saved; please try again later.")
    follow_redirect!
    expect(response.body).to include("Judge Unavailable")
  end

  it "shows submission times in the application time zone" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")

    travel_to(Time.utc(2026, 10, 20, 20)) do
      attempt = user.practice_sessions.create!(problem: problem, started_at: Time.current)
        .attempts.create!(code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby")

      get attempt_path(attempt)
      expect(response.body).to include("2026-10-20 15:00 CDT")
      get attempts_path
      expect(response.body).to include("2026-10-20 15:00 CDT")
    end
  end
end
