require "rails_helper"

RSpec.describe Judge::HerokuDynoRunner do
  before { seed_judge }

  around do |example|
    previous_database_url = ENV["DATABASE_URL"]
    previous_secret_key_base = ENV["SECRET_KEY_BASE"]
    previous_judge_token = ENV["JUDGE_HEROKU_TOKEN"]
    ENV["DATABASE_URL"] = "postgres://secret"
    ENV["SECRET_KEY_BASE"] = "secret"
    ENV["JUDGE_HEROKU_TOKEN"] = "platform-secret"
    example.run
  ensure
    ENV["DATABASE_URL"] = previous_database_url
    ENV["SECRET_KEY_BASE"] = previous_secret_key_base
    ENV["JUDGE_HEROKU_TOKEN"] = previous_judge_token
  end

  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:inputs) { problem.test_cases.order(:position).map(&:input) }
  let(:api) { instance_double(Judge::HerokuDynoRunner::Api) }
  let(:rendezvous) { instance_double(Judge::HerokuDynoRunner::Rendezvous) }

  it "uses a prepared single-use session and closes it when execution fails" do
    pool = instance_double(Judge::HerokuPool)
    session = double("prepared session")
    expect(api).not_to receive(:create_dyno)
    expect(pool).to receive(:checkout).and_return(session)
    expect(session).to receive(:call).with(input: kind_of(String), timeout: 55).and_raise(IOError)
    expect(session).to receive(:close)
    runner = described_class.new(app: "codecoach", token: "secret", api: api, pool: pool)
    expect(runner.call(code: "solution", language: "ruby", problem: problem, inputs: inputs))
      .to eq("status" => "Judge Unavailable", "outputs" => [])
  end

  it "requests the judge process type with scrubbed config values" do
    response = Struct.new(:code, :body)
    api_class = Class.new(described_class::Api) do
      attr_reader :request_body

      define_method(:request) do |_uri, request|
        @request_body = JSON.parse(request.body)
        response.new("201", JSON.generate(attach_url: "rendezvous://example.test:5000/secret"))
      end
    end
    client = api_class.new

    client.create_dyno(app: "codecoach", token: "platform-secret", env: { "DATABASE_URL" => "" })

    expect(client.request_body).to include(
      "attach" => true,
      "type" => "judge",
      "env" => { "DATABASE_URL" => "" },
      "time_to_live" => 60
    )
  end

  it "creates an attached judge dyno and sends source only over stdin" do
    expect(api).to receive(:create_dyno) do |app:, token:, env:|
      expect(app).to eq("codecoach-judge")
      expect(token).to eq("platform-secret")
      expect(env).to include(
        "DATABASE_URL" => "",
        "JUDGE_HEROKU_TOKEN" => "",
        "SECRET_KEY_BASE" => ""
      )
      expect(env.values).to all(eq(""))
      "rendezvous://rendezvous.runtime.heroku.com:5000/attach-secret"
    end
    expect(rendezvous).to receive(:call) do |url:, input:, timeout:|
      payload = JSON.parse(input)
      expect(url).to eq("rendezvous://rendezvous.runtime.heroku.com:5000/attach-secret")
      expect(input).not_to include("platform-secret")
      expect(payload).to include("language" => "go", "runtime" => "Go 1.27.3", "inputs" => inputs)
      expect(payload).not_to have_key("expected_output")
      expect(timeout).to be > 15
      JSON.generate(status: "ok", outputs: problem.test_cases.order(:position).map(&:expected_output),
        runtime: "Go 1.27.3")
    end

    result = described_class.new(
      app: "codecoach-judge", token: "platform-secret", api: api, rendezvous: rendezvous
    ).call(code: LanguageSolutions::CORRECT.fetch("go").fetch(problem.slug), language: "go",
      problem: problem, inputs: inputs)

    expect(result).to include("status" => "ok", "runtime" => "Go 1.27.3")
    expect(result.fetch("outputs")).to eq(problem.test_cases.order(:position).map(&:expected_output))
  end

  it "fails closed when configuration is missing or malformed" do
    expect(api).not_to receive(:create_dyno)
    expect(rendezvous).not_to receive(:call)

    [
      [ nil, "secret" ],
      [ "INVALID_APP", "secret" ],
      [ "codecoach-judge", nil ],
      [ "codecoach-judge", "secret\nheader" ]
    ].each do |app, token|
      result = described_class.new(app: app, token: token, api: api, rendezvous: rendezvous).call(
        code: "solution", language: "go", problem: problem, inputs: inputs)
      expect(result).to eq("status" => "Judge Unavailable", "outputs" => [])
    end
  end

  it "fails closed on Platform API, rendezvous, and result failures" do
    runner = described_class.new(
      app: "codecoach-judge", token: "platform-secret", api: api, rendezvous: rendezvous
    )

    allow(api).to receive(:create_dyno).and_return("rendezvous://rendezvous.runtime.heroku.com:5000/secret")
    [
      "not json",
      JSON.generate(status: "ok", outputs: [], runtime: "Go 1.26"),
      JSON.generate(status: "invented", outputs: [], runtime: "Go 1.27.3")
    ].each do |response|
      allow(rendezvous).to receive(:call).and_return(response)
      expect(runner.call(code: "solution", language: "go", problem: problem, inputs: inputs))
        .to eq("status" => "Judge Unavailable", "outputs" => [])
    end

    allow(api).to receive(:create_dyno).and_raise(Net::ReadTimeout)
    expect(runner.call(code: "solution", language: "go", problem: problem, inputs: inputs))
      .to eq("status" => "Judge Unavailable", "outputs" => [])
  end
end
