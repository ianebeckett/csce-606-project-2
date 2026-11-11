require "rails_helper"

RSpec.describe Judge::RemoteRunner do
  before { seed_judge }

  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:inputs) { problem.test_cases.order(:position).map(&:input) }
  let(:transport) { instance_double(Judge::RemoteRunner::Transport) }

  it "sends source without expected outputs and authenticates outside the JSON body" do
    expect(transport).to receive(:call) do |uri:, token:, body:, open_timeout:, read_timeout:|
      payload = JSON.parse(body)
      expect(uri.to_s).to eq("https://judge.example.test/v1/execute")
      expect(token).to eq("server-secret")
      expect(body).not_to include("server-secret")
      expect(payload).to include(
        "language" => "python",
        "runtime" => "Python 3.15.2",
        "inputs" => inputs
      )
      expect(payload).not_to have_key("expected_output")
      expect(open_timeout).to eq(3)
      expect(read_timeout).to be > 15
      described_class::Response.new(
        200,
        JSON.generate(status: "ok", outputs: problem.test_cases.order(:position).map(&:expected_output),
          runtime: "Python 3.15.2")
      )
    end

    result = described_class.new(
      url: "https://judge.example.test/v1/execute",
      token: "server-secret",
      transport: transport
    ).call(code: LanguageSolutions::CORRECT.fetch("python").fetch(problem.slug), language: "python",
      problem: problem, inputs: inputs)

    expect(result).to include("status" => "ok", "runtime" => "Python 3.15.2")
    expect(result.fetch("outputs")).to eq(problem.test_cases.order(:position).map(&:expected_output))
  end

  it "fails closed for missing, non-HTTPS, or header-breaking configuration" do
    expect(transport).not_to receive(:call)

    [
      [ nil, "secret" ],
      [ "http://judge.example.test/run", "secret" ],
      [ "https://judge.example.test/run", nil ],
      [ "https://judge.example.test/run", "secret\nheader" ]
    ].each do |url, token|
      result = described_class.new(url: url, token: token, transport: transport).call(
        code: "solution", language: "python", problem: problem, inputs: inputs)
      expect(result).to eq("status" => "Judge Unavailable", "outputs" => [])
    end
  end

  it "fails closed without exposing remote failures or accepting another runtime" do
    responses = [
      described_class::Response.new(500, "server-secret internal failure"),
      described_class::Response.new(200, "not json"),
      described_class::Response.new(200, JSON.generate(status: "ok", outputs: [], runtime: "Python 3.14")),
      described_class::Response.new(200, JSON.generate(status: "invented", outputs: [], runtime: "Python 3.15.2"))
    ]
    allow(transport).to receive(:call).and_return(*responses)
    runner = described_class.new(url: "https://judge.example.test/run", token: "server-secret", transport: transport)

    responses.length.times do
      expect(runner.call(code: "solution", language: "python", problem: problem, inputs: inputs))
        .to eq("status" => "Judge Unavailable", "outputs" => [])
    end
  end

  it "fails closed on DNS and TLS errors" do
    [ SocketError, OpenSSL::SSL::SSLError ].each do |error_class|
      allow(transport).to receive(:call).and_raise(error_class, "failure for server-secret")

      result = described_class.new(
        url: "https://judge.example.test/run", token: "server-secret", transport: transport
      ).call(code: "solution", language: "python", problem: problem, inputs: inputs)

      expect(result).to eq("status" => "Judge Unavailable", "outputs" => [])
    end
  end
end
