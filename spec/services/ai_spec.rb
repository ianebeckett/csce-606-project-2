require "rails_helper"

RSpec.describe Ai do
  include CodeReviewHelpers

  after { use_ai_client(nil) }

  def expect_unconfigured
    expect { Ai.client.complete(system: "s", prompt: "p") }.to raise_error(Ai::Error, /No AI provider/)
  end

  it "returns the configured client" do
    client = Ai::FakeClient.new(reply: "{}")
    use_ai_client(client)

    expect(Ai.client).to be(client)
  end

  it "falls back to the unconfigured client when the setting was never assigned" do
    allow(Rails.configuration).to receive(:x).and_return(Rails::Application::Configuration::Custom.new)

    expect_unconfigured
  end

  it "falls back to the unconfigured client when the setting is nil" do
    use_ai_client(nil)

    expect_unconfigured
  end
end
