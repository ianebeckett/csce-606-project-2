module Ai
  # The AI provider is set per environment (config.x.ai_client) so tests can
  # inject a fake and the team can swap providers without touching callers.
  def self.client
    Rails.configuration.x.ai_client || UnconfiguredClient.new
  end
end
