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
        time_complexity: complexity["time"],
        space_complexity: complexity["space"],
        suggestions: Array(data["suggestions"]).filter_map { |s| build_suggestion(s) }
      )
    end

    private

    def decode(raw)
      text = raw.to_s
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

    # Keeps the AI's line numbers inside the submitted code. A start line
    # that doesn't exist becomes a general comment ([nil, nil]).
    def line_range(start, finish)
      start = Integer(start, exception: false)
      return [ nil, nil ] if start.nil? || start < 1 || start > @line_count

      finish = Integer(finish, exception: false) || start
      start, finish = finish, start if finish < start
      [ start.clamp(1, @line_count), finish.clamp(1, @line_count) ]
    end
  end
end
