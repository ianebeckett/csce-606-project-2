module CodeReview
  # Turns the AI's raw JSON reply into a Review. Strict about what the
  # review needs (valid JSON, a summary); forgiving about the rest, since
  # AI output is unreliable.
  class Parser
    CATEGORIES = %w[correctness complexity edge_case anti_pattern].freeze

    # Models often wrap JSON in ```json fences even when asked not to.
    CODE_FENCE = /\A\s*```(?:json)?\s*\n?(.*?)\n?```\s*\z/m

    # AI text ends up on a page, so cap it rather than trust its length.
    MAX_TEXT_LENGTH = 2_000

    def self.parse(raw, code:)
      new(code).parse(raw)
    end

    def initialize(code)
      @line_count = code.lines.size
    end

    def parse(raw)
      data = decode(raw)
      summary = data["summary"]
      raise InvalidResponse, "missing summary" unless summary.is_a?(String) && summary.present?

      complexity = data["complexity"].is_a?(Hash) ? data["complexity"] : {}

      Review.new(
        summary: limit(summary),
        time_complexity: optional_text(complexity["time"]),
        space_complexity: optional_text(complexity["space"]),
        suggestions: Array(data["suggestions"]).filter_map { |s| build_suggestion(s) }
      )
    end

    private

    def decode(raw)
      text = raw.to_s
      # Matching a regex against invalid UTF-8 raises ArgumentError, which
      # callers don't rescue, so reject it as an unusable reply first.
      raise InvalidResponse, "response is not valid UTF-8" unless text.valid_encoding?

      text = Regexp.last_match(1) if text =~ CODE_FENCE
      data = JSON.parse(text)
      raise InvalidResponse, "expected a JSON object" unless data.is_a?(Hash)

      data
    rescue JSON::ParserError => e
      raise InvalidResponse, "response is not valid JSON: #{e.message}"
    end

    # Returns nil for an invalid suggestion so one bad item doesn't
    # discard the whole review.
    def build_suggestion(item)
      return unless item.is_a?(Hash)
      return unless CATEGORIES.include?(item["category"])

      message = item["message"]
      return unless message.is_a?(String) && message.strip.present?

      line_start, line_end = line_range(item["line_start"], item["line_end"])
      Suggestion.new(category: item["category"], line_start:, line_end:, message: limit(message))
    end

    def limit(text)
      text.strip.truncate(MAX_TEXT_LENGTH)
    end

    def optional_text(value)
      limit(value) if value.is_a?(String) && value.strip.present?
    end

    # Keeps the AI's line numbers inside the submitted code. A start line
    # that doesn't exist becomes a general comment ([nil, nil]).
    def line_range(start, finish)
      start = line_number(start)
      return [ nil, nil ] if start.nil? || start < 1 || start > @line_count

      finish = finish.nil? ? start : line_number(finish)
      return [ nil, nil ] if finish.nil?

      start, finish = finish, start if finish < start
      [ start.clamp(1, @line_count), finish.clamp(1, @line_count) ]
    end

    # Integer() truncates floats (2.9 becomes 2), which would attach the
    # advice to the wrong line, so only whole numbers count.
    def line_number(value)
      return value.to_i if value.is_a?(Float) && value.finite? && value == value.floor
      return if value.is_a?(Float)

      Integer(value, exception: false)
    end
  end
end
