module CodeReview
  Suggestion = Data.define(:category, :line_start, :line_end, :message)
end
