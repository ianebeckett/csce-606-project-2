module Ai
  # Stand-in AI provider for tests and local development. Real clients
  # follow the same contract: complete(system:, prompt:) returns the reply
  # text, or raises Ai::Error on failure.
  class FakeClient
    attr_reader :last_system, :last_prompt

    def initialize(reply: nil, error: nil)
      @reply = reply
      @error = error
    end

    def complete(system:, prompt:)
      @last_system = system
      @last_prompt = prompt
      raise @error if @error

      @reply
    end
  end
end
