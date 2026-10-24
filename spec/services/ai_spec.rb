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

  describe ".client_from_env" do
    it "builds an OpenAI client with the default model when a key is set" do
      client = Ai.client_from_env("OPENAI_API_KEY" => "sk-test")

      expect(client).to be_a(Ai::OpenAiClient)
      expect(client.model).to eq("gpt-6-luna")
    end

    it "uses the model from OPENAI_MODEL when set" do
      expect(Ai.client_from_env("OPENAI_API_KEY" => "sk-test", "OPENAI_MODEL" => "gpt-6.1-sol").model).to eq("gpt-6.1-sol")
    end

    it "returns nil when no key is set" do
      expect(Ai.client_from_env({})).to be_nil
      expect(Ai.client_from_env("OPENAI_API_KEY" => " ")).to be_nil
    end
  end
end
