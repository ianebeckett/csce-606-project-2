module Ai
  class UnconfiguredClient
    def complete(system:, prompt:, schema: nil)
      raise NotConfigured, "OPENAI_API_KEY is not set"
    end
  end
end
