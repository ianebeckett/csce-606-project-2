Rails.application.config.to_prepare do
  Rails.configuration.x.ai_client = Ai.client_from_env unless Rails.env.test?
end
