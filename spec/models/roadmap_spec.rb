require "rails_helper"

RSpec.describe Roadmap do
  before { seed_judge }
  let(:user) { create_user }
  let(:arrays) { Topic.find_by!(name: "Arrays & Hashing") }
  let(:pointers) { Topic.find_by!(name: "Two Pointers") }
  let(:window) { Topic.find_by!(name: "Sliding Window") }

  def record_result(problem, result, owner: user)
    owner.practice_sessions.for_today(problem).attempts.create!(
      code: problem.starter_code, language: "ruby", judge_result: result)
  end

  it "starts root topics In Progress and locks dependent topics" do
    roadmap = described_class.new(user)
    expect(roadmap.state(arrays)).to eq("In Progress")
    expect(roadmap.state(pointers)).to eq("Locked")
    expect(roadmap.state(window)).to eq("Locked")
    expect(roadmap.solved_ids).to be_empty
  end

  it "requires an Accepted submission for every problem before mastering a nonempty topic" do
    extra = arrays.problems.first.dup
    extra.update!(slug: "another-array-problem", title: "Another array problem")
    problem = arrays.problems.order(:id).first
    record_result(problem, Attempt::WRONG_ANSWER)
    expect(described_class.new(user).solved_ids).to be_empty
    record_result(problem, Attempt::ACCEPTED)
    expect(described_class.new(user).state(arrays)).to eq("In Progress")
    record_result(extra, Attempt::ACCEPTED)
    roadmap = described_class.new(user)
    expect(roadmap.state(arrays)).to eq("Mastered")
    expect(roadmap.state(pointers)).to eq("In Progress")
    expect(roadmap.state(window)).to eq("Locked")
  end

  it "keeps completed problems completed after failed retries and counts each once" do
    problem = arrays.problems.first
    [ Attempt::ACCEPTED, Attempt::ACCEPTED, Attempt::WRONG_ANSWER ].each { |result| record_result(problem, result) }
    expect(described_class.new(user).solved_ids).to eq([ problem.id ])
    expect(described_class.new(user).state(arrays)).to eq("Mastered")
  end

  it "requires all prerequisites, including their ancestors, even for previously solved topics" do
    TopicPrerequisite.create!(topic: window, prerequisite_topic: Topic.find_by!(name: "Stack"))
    record_result(pointers.problems.first, Attempt::ACCEPTED)
    expect(described_class.new(user).state(pointers)).to eq("Locked")
    record_result(arrays.problems.first, Attempt::ACCEPTED)
    expect(described_class.new(user).state(window)).to eq("Locked")
    record_result(Problem.find_by!(slug: "valid-parentheses"), Attempt::ACCEPTED)
    expect(described_class.new(user).state(window)).to eq("In Progress")
  end

  it "never masters an empty topic or uses another member's progress" do
    empty = Topic.create!(name: "Empty", position: 6)
    record_result(arrays.problems.first, Attempt::ACCEPTED, owner: create_user(email: "other@example.com"))
    roadmap = described_class.new(user)
    expect(roadmap.state(empty)).to eq("In Progress")
    expect(roadmap.state(arrays)).to eq("In Progress")
    expect(roadmap.state(pointers)).to eq("Locked")
    expect(roadmap.solved_ids).to be_empty
  end

  it "seeds prerequisites idempotently without changing saved progress" do
    record_result(arrays.problems.first, Attempt::ACCEPTED)
    expect { seed_judge }.not_to change { [ TopicPrerequisite.count, Attempt.count ] }
    expect(TopicPrerequisite.count).to eq(5)
    expect(pointers.prerequisites).to contain_exactly(arrays)
    expect(window.prerequisites).to contain_exactly(pointers)
  end
end
