module CodeReview
  Review = Data.define(:summary, :time_complexity, :space_complexity, :suggestions) do
    # Same shape as the AI's reply, so a saved review is read back with Parser.
    def to_json(*)
      { summary:, complexity: { time: time_complexity, space: space_complexity }, suggestions: suggestions.map(&:to_h) }.to_json
    end
  end
end
