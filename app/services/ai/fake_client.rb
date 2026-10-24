module Ai
  class FakeClient
    attr_reader :last_system, :last_prompt, :last_schema

    def initialize(reply: nil, error: nil)
      @reply = reply
      @error = error
    end

    def complete(system:, prompt:, schema: nil)
      @last_system = system
      @last_prompt = prompt
      @last_schema = schema
      raise @error if @error

      @reply
    end
  end
end
