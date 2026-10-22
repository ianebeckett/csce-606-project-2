require "rails_helper"

RSpec.describe "Online Judge models" do
  before { seed_judge }

  it "seeds one attributed Easy problem for every requested topic with at least five cases" do
    expect(Topic.order(:position).pluck(:name)).to eq([
      "Arrays & Hashing", "Two Pointers", "Stack", "Binary Search", "Sliding Window", "Linked List"
    ])
    expect(Problem.count).to eq(6)
    Problem.find_each do |problem|
      expect(problem).to be_ready_for_judging
      expect(problem.difficulty).to eq("Easy")
      expect(problem.source_url).to start_with("https://leetcode.com/problems/")
      expect(problem.test_cases.count).to be >= 5
    end
  end

  it "seeds idempotently without erasing attempts" do
    user = create_user
    session = user.practice_sessions.create!(problem: Problem.first, started_at: Time.current)
    session.attempts.create!(code: "def contains_duplicate(nums); false; end", language: "ruby")
    expect { seed_judge }.not_to change { [ Problem.count, TestCase.count, Attempt.count ] }
  end

  it "keeps users unique and authenticates with a password hash" do
    user = create_user(email: "  LEARNER@example.com  ")
    expect(user.email).to eq("learner@example.com")
    expect(user.authenticate("correct-horse-battery")).to eq(user)
    expect(user.authenticate("wrong")).to be(false)
    expect(User.new(email: user.email, password: "correct-horse-battery")).not_to be_valid
    expect(User.new(email: "bad", password: "short", role: "admin")).not_to be_valid
  end

  it "rejects non-Ruby, empty, and excessively large submissions" do
    session = create_user.practice_sessions.create!(problem: Problem.first, started_at: Time.current)
    expect(session.attempts.new(code: "puts 1", language: "python")).not_to be_valid
    expect(session.attempts.new(code: "", language: "ruby")).not_to be_valid
    expect(session.attempts.new(code: "x" * 65_537, language: "ruby")).not_to be_valid
  end

  it "preserves JSON false and rejects malformed case inputs" do
    test_case = Problem.first.test_cases.new(input: { args: [ [ 1, 2 ] ] }, expected_output: false, position: 100)
    expect(test_case).to be_valid
    test_case.input = { arbitrary: "data" }
    expect(test_case).not_to be_valid
  end
end
