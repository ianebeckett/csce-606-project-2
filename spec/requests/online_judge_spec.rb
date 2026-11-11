require "rails_helper"

RSpec.describe "Online Judge requests", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  before { seed_judge }
  let(:user) { create_user }

  it "rejects a full shared queue without saving or enqueueing the new source" do
    stub_const("Judge::Queue::MAX_PENDING", 2)
    problem = Problem.first
    other = create_user(email: "other@example.com")
    session = other.practice_sessions.for_today(problem)
    session.attempts.create!(code: "private source", language: "ruby", total_cases: 6,
      judging_started_at: 10.seconds.ago)
    session.attempts.create!(code: "other pending source", language: "ruby", total_cases: 6)
    sign_in(user)
    code = "def contains_duplicate(nums); nums.uniq.length < nums.length; end"

    expect do
      post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } }
    end.not_to change(Attempt, :count)

    expect(enqueued_jobs).to be_empty
    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers.fetch("Retry-After")).to eq("55")
    expect(response.body).to include("The judge is at capacity (2 pending submissions)", "not queued", "estimate")
    expect(response.body).to include(ERB::Util.html_escape(code))
    expect(response.body).not_to include("private source", "other pending source")

    session.attempts.first.update!(judge_result: "Runtime Error")
    expect do
      post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } }
    end.to change(Attempt, :count).by(1).and change { enqueued_jobs.size }.by(1)
    expect(response).to redirect_to(attempt_path(user.attempts.sole))
  end

  it "shows the estimated wait and then the running submission without changing its verdict" do
    sign_in(user)
    problem = Problem.first
    session = user.practice_sessions.for_today(problem)
    travel_to(Time.utc(2026, 11, 4, 18)) do
      first = session.attempts.create!(code: "private older source", total_cases: 6, judging_started_at: 10.seconds.ago)
      second = session.attempts.create!(code: "queued source", total_cases: 7)
      attempt = session.attempts.create!(code: "my source", total_cases: 6)
      session.attempts.create!(code: "later source", total_cases: 6)

      get attempt_path(attempt)
      expect(response.body).to include("2 submissions ahead", "about 115 seconds", "estimate")
      expect(response.body).not_to include("private older source", "queued source", "later source")

      first.update!(judge_result: "Accepted")
      second.update!(judge_result: "Wrong Answer")
      attempt.update!(judging_started_at: Time.current)
      get attempt_path(attempt)
      expect(response.body).to include("Judging has started", "Refresh result")
      expect(response.body).not_to include("submissions ahead")
      expect(attempt.reload.judge_result).to eq("Pending")
    end
  end

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
    complete_prerequisites(user, Topic.find_by!(name: "Stack"))
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

  it "selects one fixed version of each supported language without JavaScript" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")

    {
      "ruby" => "Ruby 4.0.1",
      "python" => "Python 3.15.2",
      "go" => "Go 1.27.3",
      "cpp" => "C++23 (GCC 16.2.0)"
    }.each do |language, version|
      get problem_path(problem, language: language)
      expect(response.body).to include(version)
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('input[name="attempt[language]"]')["value"]).to eq(language)
      expect(response.body).to include("#{Attempt.language_name(language)} source code")
    end
  end

  it "rejects a language that is not offered by the server" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")

    expect do
      post problem_attempts_path(problem), params: { attempt: { code: "solution", language: "javascript" } }
    end.not_to change(Attempt, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("is not supported")
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

  it "queues judging and preserves infrastructure failures" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")
    command = instance_double(Judge::Command)
    allow(command).to receive(:call).and_raise(Errno::EACCES, "docker")
    allow(Judge::Command).to receive(:new).and_return(command)

    expect do
      post problem_attempts_path(problem), params: {
        attempt: { code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby" }
      }
    end.to change(Attempt, :count).by(1).and change { enqueued_jobs.size }.by(1)

    attempt = Attempt.order(:id).last
    expect(response).to redirect_to(attempt_path(attempt))
    expect(attempt.judge_result).to eq("Pending")
    expect(attempt.total_cases).to eq(6)
    follow_redirect!
    expect(response.body).to include("Pending")
    expect(response.body).to include("Refresh result")
    expect(response.body).not_to include('http-equiv="refresh"')

    perform_enqueued_jobs

    expect(attempt.reload.judge_result).to eq("Judge Unavailable")
    expect(attempt.error_message).to eq("The judge is temporarily unavailable. Please try again.")
    get attempt_path(attempt)
    expect(response.body).to include("Judge Unavailable")
    expect(response.body).not_to include("Refresh result")
  end

  it "keeps the submission when enqueueing fails" do
    sign_in(user)
    problem = Problem.first
    code = RubySolutions::CORRECT.fetch(problem.slug)
    [ ActiveJob::EnqueueError, ActiveRecord::ActiveRecordError ].each do |error_class|
      error = error_class.new("queue unavailable")
      allow(JudgeSubmissionJob.queue_adapter).to receive(:enqueue).and_raise(error)
      expect(Rails.error).to receive(:report).with(error) if error.is_a?(ActiveRecord::ActiveRecordError)

      expect do
        post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } }
      end.to change(Attempt, :count).by(1)

      attempt = Attempt.order(:id).last
      expect(response).to redirect_to(attempt_path(attempt))
      expect(attempt).to have_attributes(code: code, judge_result: "Judge Unavailable", total_cases: 6)
      follow_redirect!
      expect(response.body).to include("Your code was saved; please try again later.")
    end
  end

  it "restores starter code after blank submissions without rewriting history" do
    sign_in(user)
    problem = Problem.find_by!(slug: "contains-duplicate")

    [ "", " \t\n" ].each do |code|
      post problem_attempts_path(problem), params: { attempt: { code: code, language: "ruby" } }
      perform_enqueued_jobs
      attempt = user.attempts.order(:id).last
      get problem_path(problem)

      expect(response.body).to include(problem.starter_code)
      expect(attempt.reload.code).to eq(code)
      expect(attempt.judge_result).to eq("Runtime Error")
    end
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
