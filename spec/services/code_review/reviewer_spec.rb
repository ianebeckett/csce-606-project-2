require "rails_helper"

RSpec.describe CodeReview::Reviewer do
  let(:code) { "def add(a, b)\n  a - b\nend\n" }
  let(:reply) do
    {
      summary: "Subtracts instead of adds.",
      complexity: { time: "O(1)", space: "O(1)" },
      suggestions: [ { category: "correctness", line_start: 2, message: "Use + instead of -." } ]
    }.to_json
  end
  let(:client) { Ai::FakeClient.new(reply: reply) }

  def review(**overrides)
    described_class.new(client: client).call(
      code: code, language: "ruby", problem: "Return the sum of a and b.",
      judge_result: "Wrong Answer (0/5 passed)", **overrides
    )
  end

  it "returns the parsed review from the AI reply" do
    result = review

    expect(result.summary).to eq("Subtracts instead of adds.")
    expect(result.suggestions.first.line_start).to eq(2)
  end

  it "sends the code with line numbers so the AI can reference lines" do
    review

    expect(client.last_prompt).to include("1 | def add(a, b)")
    expect(client.last_prompt).to include("2 |   a - b")
  end

  it "sends the problem, language, and judge result" do
    review

    expect(client.last_prompt).to include("Return the sum of a and b.")
    expect(client.last_prompt).to include("ruby")
    expect(client.last_prompt).to include("Wrong Answer (0/5 passed)")
  end

  it "asks for every review category in the system instructions" do
    review

    %w[correctness complexity edge_case anti_pattern].each do |category|
      expect(client.last_system).to include(category)
    end
  end

  it "omits the judge section when the code has not been judged" do
    review(judge_result: nil)

    expect(client.last_prompt).not_to include("Judge result")
  end

  it "raises Unavailable when the AI service fails" do
    client = Ai::FakeClient.new(error: Ai::Error.new("timeout"))

    expect { described_class.new(client: client).call(code: code, language: "ruby", problem: "p") }
      .to raise_error(CodeReview::Unavailable)
  end

  it "raises an InvalidResponse (also a CodeReview::Error) for an unusable reply" do
    client = Ai::FakeClient.new(reply: "not json")

    expect { described_class.new(client: client).call(code: code, language: "ruby", problem: "p") }
      .to raise_error(CodeReview::InvalidResponse) { |e| expect(e).to be_a(CodeReview::Error) }
  end
end
