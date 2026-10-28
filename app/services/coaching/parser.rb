module Coaching
  class Parser
    Reply = Data.define(:message, :advance)

    # Models often wrap JSON in ```json fences even when asked not to.
    CODE_FENCE = /\A\s*```(?:json)?\s*\n?(.*?)\n?```\s*\z/m

    def self.parse(raw)
      text = raw.to_s.dup.force_encoding(Encoding::UTF_8).scrub("")
      text = Regexp.last_match(1) if text =~ CODE_FENCE
      data = JSON.parse(text)
      raise InvalidResponse, "expected a JSON object" unless data.is_a?(Hash)

      message = data["message"]
      raise InvalidResponse, "missing message" unless message.is_a?(String) && message.strip.present?

      # Only a literal true advances, so a malformed reply never unlocks the editor.
      Reply.new(message: message.strip, advance: data["advance"] == true)
    rescue JSON::ParserError => e
      raise InvalidResponse, "response is not valid JSON: #{e.message}"
    end
  end
end
