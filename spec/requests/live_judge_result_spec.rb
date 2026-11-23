require "rails_helper"

RSpec.describe "Live judge result", type: :request do
  before { seed_judge }

  let(:user) { create_user }
  let(:attempt) do
    user.practice_sessions.for_today(Problem.first).attempts.create!(code: "my source", total_cases: 6)
  end

  def status_json
    get attempt_path(attempt, format: :json)
    response.parsed_body
  end

  it "reports a pending verdict as JSON" do
    sign_in(user)

    expect(status_json).to eq("judge_result" => "Pending", "pending" => true)
    expect(response.media_type).to eq("application/json")
  end

  it "reports a finished verdict as JSON" do
    sign_in(user)
    attempt.update!(judge_result: Attempt::ACCEPTED, passed_cases: 6)

    expect(status_json).to eq("judge_result" => "Accepted", "pending" => false)
  end

  it "keeps another member's verdict private" do
    sign_in(create_user(email: "other@example.com"))

    get attempt_path(attempt, format: :json)

    expect(response).to have_http_status(:not_found)
  end

  it "asks the page to poll only while the verdict is pending" do
    sign_in(user)

    get attempt_path(attempt)
    expect(response.body).to include("data-attempt-status-url=\"#{attempt_path(attempt, format: :json)}\"",
                                     "This page updates on its own", "Refresh result")

    attempt.update!(judge_result: Attempt::ACCEPTED, passed_cases: 6)
    get attempt_path(attempt)
    expect(response.body).not_to include("data-attempt-status-url", "This page updates on its own")
    expect(response.body).to include("result-card result-accepted", "data-attempt-id=\"#{attempt.id}\"")
  end
end
