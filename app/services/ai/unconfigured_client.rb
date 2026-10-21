module Ai
  # Used until a real provider is configured, so AI features fail with a
  # clear message instead of crashing.
  class UnconfiguredClient
    def complete(system:, prompt:)
      raise Error, "No AI provider is configured."
    end
  end
end
