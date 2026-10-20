require "rails_helper"

RSpec.describe CodeReview::Parser do
  let(:code) { "def two_sum(nums, target)\n  nums.each do |n|\n  end\nend\n" } # 4 lines

  def parse(payload)
    described_class.parse(payload.is_a?(String) ? payload : payload.to_json, code: code)
  end

  let(:valid_payload) do
    {
      summary: "Brute force works but is quadratic.",
      complexity: { time: "O(n^2)", space: "O(1)" },
      suggestions: [
        { category: "complexity", line_start: 2, line_end: 3, message: "Use a hash map for O(n)." }
      ]
    }
  end

  describe "a well-formed response" do
    it "returns the summary, complexity, and line-tagged suggestions" do
      review = parse(valid_payload)

      expect(review.summary).to eq("Brute force works but is quadratic.")
      expect(review.time_complexity).to eq("O(n^2)")
      expect(review.space_complexity).to eq("O(1)")
      expect(review.suggestions.size).to eq(1)

      suggestion = review.suggestions.first
      expect(suggestion.category).to eq("complexity")
      expect(suggestion.line_start).to eq(2)
      expect(suggestion.line_end).to eq(3)
      expect(suggestion.message).to eq("Use a hash map for O(n).")
    end

    it "accepts JSON wrapped in a markdown code fence" do
      review = parse("```json\n#{valid_payload.to_json}\n```")

      expect(review.summary).to eq("Brute force works but is quadratic.")
    end
  end

  describe "an unusable response" do
    it "raises InvalidResponse for non-JSON text" do
      expect { parse("Sorry, I can't help with that.") }
        .to raise_error(CodeReview::InvalidResponse)
    end

    it "raises InvalidResponse when the summary is missing" do
      expect { parse(valid_payload.except(:summary)) }
        .to raise_error(CodeReview::InvalidResponse)
    end

    it "raises InvalidResponse when the JSON is not an object" do
      expect { parse("[1, 2]") }.to raise_error(CodeReview::InvalidResponse)
    end
  end

  describe "suggestion validation" do
    def suggestions_for(*suggestions)
      parse(valid_payload.merge(suggestions: suggestions)).suggestions
    end

    it "drops suggestions with an unknown category but keeps valid ones" do
      result = suggestions_for(
        { category: "vibes", line_start: 1, message: "Nice." },
        { category: "edge_case", line_start: 1, message: "Empty array?" }
      )

      expect(result.map(&:category)).to eq([ "edge_case" ])
    end

    it "drops suggestions without a message" do
      expect(suggestions_for({ category: "correctness", line_start: 1, message: "  " })).to be_empty
    end

    it "treats a suggestion with no line numbers as a general comment" do
      suggestion = suggestions_for({ category: "anti_pattern", message: "Name variables clearly." }).first

      expect(suggestion.line_start).to be_nil
      expect(suggestion.line_end).to be_nil
    end

    it "uses line_start as line_end when line_end is missing" do
      suggestion = suggestions_for({ category: "correctness", line_start: 2, message: "Off by one." }).first

      expect(suggestion.line_end).to eq(2)
    end

    it "treats a start line beyond the code as a general comment" do
      suggestion = suggestions_for({ category: "correctness", line_start: 99, message: "Hallucinated line." }).first

      expect(suggestion.line_start).to be_nil
      expect(suggestion.line_end).to be_nil
    end

    it "clamps an end line beyond the code to the last line" do
      suggestion = suggestions_for({ category: "correctness", line_start: 3, line_end: 99, message: "x" }).first

      expect(suggestion.line_end).to eq(4)
    end

    it "swaps a reversed line range" do
      suggestion = suggestions_for({ category: "correctness", line_start: 3, line_end: 1, message: "x" }).first

      expect([ suggestion.line_start, suggestion.line_end ]).to eq([ 1, 3 ])
    end

    it "treats a missing suggestions list as no suggestions" do
      expect(parse(valid_payload.except(:suggestions)).suggestions).to eq([])
    end
  end
end
