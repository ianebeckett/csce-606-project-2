require "rails_helper"

RSpec.describe "Roadmap access", type: :request do
  before { seed_judge }
  let(:user) { create_user }
  let(:arrays) { Topic.find_by!(name: "Arrays & Hashing") }
  let(:pointers) { Topic.find_by!(name: "Two Pointers") }
  let(:locked_problem) { pointers.problems.first }

  it "requires login for the roadmap, filtered topics, problems, and submissions" do
    [ root_path, problems_path, problems_path(topic: pointers.id), problem_path(locked_problem) ].each do |path|
      get path
      expect(response).to redirect_to(new_session_path)
    end
    expect do
      post problem_attempts_path(locked_problem), params: { attempt: { code: "puts 1", language: "ruby" } }
    end.not_to change(PracticeSession, :count)
    expect(response).to redirect_to(new_session_path)
  end

  User::ROLES.each do |role|
    it "lets #{role} members explore only unlocked problems with difficulty and completion status" do
      sign_in(create_user(role: role))
      get problems_path(topic: arrays.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Contains Duplicate", "Easy", "Not solved", "In Progress", "Locked")
      expect(response.body).not_to include("Valid Palindrome")
      get problems_path
      expect(response.body).not_to include("Valid Palindrome")
    end
  end

  it "blocks topic filters, direct problem URLs, and direct submissions without writing or judging" do
    sign_in(user)
    [ problems_path(topic: pointers.id), problem_path(locked_problem) ].each do |path|
      get path
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Topic locked", "Arrays &amp; Hashing")
      expect(response.body).not_to include(locked_problem.description)
    end
    expect(Judge::Submission).not_to receive(:new)
    expect do
      post problem_attempts_path(locked_problem), params: { attempt: { code: "puts 1", language: "ruby" } }
    end.not_to change { [ PracticeSession.count, Attempt.count ] }
    expect(response).to have_http_status(:forbidden)
  end

  it "unlocks from the current user's persisted judge results and never from request parameters" do
    other = create_user(email: "other@example.com")
    problem = arrays.problems.first
    other.practice_sessions.for_today(problem).attempts.create!(code: "private code", language: "ruby", judge_result: Attempt::ACCEPTED)
    sign_in(user)
    get problems_path(topic: pointers.id, user_id: other.id)
    expect(response).to have_http_status(:forbidden)
    user.practice_sessions.for_today(problem).attempts.create!(code: "my code", language: "ruby", judge_result: Attempt::ACCEPTED)
    get problems_path(topic: arrays.id)
    expect(response.body).to include("Mastered", "Accepted")
    expect(response.body).not_to include("private code")
    get problem_path(locked_problem)
    expect(response).to have_http_status(:ok)
  end

  it "handles empty topics, an empty roadmap, and unknown topic IDs" do
    sign_in(user)
    empty = Topic.create!(name: "Coming soon", position: 6)
    get problems_path(topic: empty.id)
    expect(response.body).to include("No problems are available in this topic yet.")
    get problems_path(topic: "missing")
    expect(response).to have_http_status(:not_found)
    Problem.destroy_all
    Topic.destroy_all
    get problems_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No topics are available yet.")
  end
end
