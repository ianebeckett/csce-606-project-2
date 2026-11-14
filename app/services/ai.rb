module Ai
  # An unassigned config.x setting is an empty options object, not nil,
  # hence .presence.
  def self.client
    Rails.configuration.x.ai_client.presence || UnconfiguredClient.new
  end

  def self.client_from_env(env = ENV)
    api_key = env["OPENAI_API_KEY"].presence
    OpenAiClient.new(api_key: api_key, model: env["OPENAI_MODEL"].presence || OpenAiClient::DEFAULT_MODEL) if api_key
  end

  # Explains why an AI feature failed, for the message shown to the member.
  # Coaching and code review re-raise Ai errors, so the original is the cause.
  def self.failure_reason(error)
    cause = error
    cause = cause.cause until cause.nil? || cause.is_a?(Error)

    case cause
    when NotConfigured then "OpenAI API key is missing: set OPENAI_API_KEY on the server"
    when Error then cause.message.chomp(".")
    else "the AI reply could not be read"
    end
  end
end
