module CodeReviewsHelper
  CATEGORY_LABELS = {
    "correctness" => "Correctness",
    "complexity" => "Complexity",
    "edge_case" => "Edge case",
    "anti_pattern" => "Anti-pattern"
  }.freeze

  def category_label(suggestion)
    CATEGORY_LABELS.fetch(suggestion.category)
  end

  # Suggestions keyed by the line they end on, so each one can be shown
  # directly under the code it refers to.
  def suggestions_by_line(review)
    review.suggestions.select(&:line_end).group_by(&:line_end)
  end

  def general_suggestions(review)
    review.suggestions.reject(&:line_end)
  end

  def suggestion_lines(suggestion)
    if suggestion.line_start == suggestion.line_end
      "Line #{suggestion.line_start}"
    else
      "Lines #{suggestion.line_start}–#{suggestion.line_end}"
    end
  end
end
