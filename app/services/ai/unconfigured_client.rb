module Ai
  class UnconfiguredClient
    def complete(system:, prompt:)
      raise Error, "No AI provider is configured."
    end
  end
end
