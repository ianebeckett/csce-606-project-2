module Ai
  class UnconfiguredClient
    def complete(system:, prompt:, schema: nil)
      raise Error, "No AI provider is configured."
    end
  end
end
