require "rails_helper"

RSpec.describe Problem, "interview content" do
  before { seed_judge }

  it "is interview-ready once seeded" do
    expect(described_class.all.map(&:interview_ready?)).to all(be(true))
    expect(described_class.count).to eq(6)
  end

  it "is not interview-ready without a twist" do
    problem = described_class.first
    problem.interview_twist = nil
    expect(problem.interview_ready?).to be(false)
  end

  it "rejects details that are not key/fact pairs" do
    problem = described_class.first
    problem.interview_details = [ { "key" => "size" } ]
    expect(problem).not_to be_valid
    expect(problem.errors[:interview_details]).to be_present
  end

  it "rejects too few or too many details" do
    problem = described_class.first
    problem.interview_details = [ { "key" => "a", "fact" => "b" } ]
    expect(problem).not_to be_valid
    problem.interview_details = Array.new(5) { { "key" => "a", "fact" => "b" } }
    expect(problem).not_to be_valid
    problem.interview_details = "nope"
    expect(problem).not_to be_valid
  end

  it "seeds Contains Duplicate from the spec" do
    problem = described_class.find_by!(slug: "contains-duplicate")
    expect(problem.interview_prompt).to eq("Given a short list of numbers, tell me whether any number repeats.")
    expect(problem.interview_details.map { |detail| detail["key"] }).to eq(%w[size range output])
    expect(problem.interview_twist).to include("100,000")
  end
end
