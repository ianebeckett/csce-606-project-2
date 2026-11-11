require "rails_helper"

RSpec.describe Judge::Runner do
  around do |example|
    previous_url = ENV["JUDGE_URL"]
    previous_token = ENV["JUDGE_TOKEN"]
    previous_heroku_app = ENV["JUDGE_HEROKU_APP"]
    previous_heroku_token = ENV["JUDGE_HEROKU_TOKEN"]
    ENV.delete("JUDGE_URL")
    ENV.delete("JUDGE_TOKEN")
    ENV.delete("JUDGE_HEROKU_APP")
    ENV.delete("JUDGE_HEROKU_TOKEN")
    example.run
  ensure
    ENV["JUDGE_URL"] = previous_url
    ENV["JUDGE_TOKEN"] = previous_token
    ENV["JUDGE_HEROKU_APP"] = previous_heroku_app
    ENV["JUDGE_HEROKU_TOKEN"] = previous_heroku_token
  end

  it "uses restricted local containers outside production" do
    expect(described_class.build).to be_a(Judge::DockerRunner)
  end

  it "uses the remote runner in production even when its configuration is missing" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
    expect(described_class.build).to be_a(Judge::RemoteRunner)
  end

  it "uses the remote runner when an endpoint is configured" do
    ENV["JUDGE_URL"] = "https://judge.example.test/run"
    ENV["JUDGE_TOKEN"] = "server-secret"
    expect(described_class.build).to be_a(Judge::RemoteRunner)
  end

  it "prefers Heroku one-off dynos when their configuration is present" do
    ENV["JUDGE_HEROKU_APP"] = "codecoach-judge"
    ENV["JUDGE_HEROKU_TOKEN"] = "platform-secret"
    ENV["JUDGE_URL"] = "https://judge.example.test/run"
    ENV["JUDGE_TOKEN"] = "server-secret"

    expect(described_class.build).to be_a(Judge::HerokuDynoRunner)
  end
end
