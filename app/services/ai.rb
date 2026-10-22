module Ai
  # An unassigned config.x setting is an empty options object, not nil,
  # hence .presence.
  def self.client
    Rails.configuration.x.ai_client.presence || UnconfiguredClient.new
  end
end
