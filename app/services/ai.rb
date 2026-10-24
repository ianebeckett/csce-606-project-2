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
end
