module CodeReview
  # line_start/line_end are nil for general comments not tied to specific lines.
  Suggestion = Data.define(:category, :line_start, :line_end, :message)
end
