module Ai
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
