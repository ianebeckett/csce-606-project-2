module Ai
  # The AI provider is set per environment (config.x.ai_client) so tests can
  # inject a fake and the team can swap providers without touching callers.
  # An unassigned config.x setting is an empty options object, not nil,
  # hence .presence.
  def self.client
    Rails.configuration.x.ai_client.presence || UnconfiguredClient.new
  end
end
