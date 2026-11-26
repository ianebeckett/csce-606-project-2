require "rails_helper"
require_relative "../../test_support/heroku_judge_stub"

RSpec.describe "Prepared Heroku judge transport" do
  before { seed_judge }
  after { @pool&.stop; @stub&.close }

  it "waits for readiness, strips secrets, sends only inputs, and retires used dynos" do
    problem = Problem.find_by!(slug: "contains-duplicate")
    inputs = problem.test_cases.order(:position).map(&:input)
    outputs = problem.test_cases.order(:position).map(&:expected_output)
    @stub = HerokuJudgeStub.new(result: JSON.generate(status: "ok", outputs: outputs, runtime: "Ruby 4.0.1"))
    @pool = Judge::HerokuPool.new(size: 2, factory: -> { @stub.runner.prepare })
    @pool.start
    Timeout.timeout(2) { sleep 0.005 until @pool.ready_count == 2 }
    runner = Judge::HerokuDynoRunner.new(app: "codecoach", token: "test-secret", pool: @pool)

    result = runner.call(code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby", problem: problem, inputs: inputs)

    expect(result).to include("status" => "ok", "outputs" => outputs)
    request = @stub.requests.pop
    expect(request).to include("size" => "Basic", "time_to_live" => 1080, "command" => "960s ruby /judge/ready.rb")
    expect(request.fetch("env").values).to all(eq(""))
    payload = @stub.payloads.pop
    expect(payload).to include("inputs" => inputs)
    expect(payload).not_to have_key("expected_output")
    expect(@stub.stopped.size).to eq(1)
    Timeout.timeout(2) { sleep 0.005 until @pool.ready_count == 2 }
  end

  it "closes the connection when the ready marker is absent" do
    socket = double("socket", write: 1, close: nil)
    allow(socket).to receive(:gets).with("\n", 1024).and_return("connected\n")
    allow(socket).to receive(:gets).with("\n", 64).and_return("unexpected\n")
    expect(socket).to receive(:close)
    rendezvous = Judge::HerokuDynoRunner::Rendezvous.new(socket_factory: ->(_) { socket })
    expect { rendezvous.prepare(url: "rendezvous://example.test:5000/id", on_close: -> { }) }
      .to raise_error(Judge::HerokuDynoRunner::InvalidResponse)
  end

  it "stops its own allocated dyno if attachment fails" do
    api = instance_double(Judge::HerokuDynoRunner::Api)
    rendezvous = instance_double(Judge::HerokuDynoRunner::Rendezvous)
    allow(api).to receive(:prepare_dyno).and_return("id" => "allocated", "attach_url" => "rendezvous://example.test:5000/id")
    allow(rendezvous).to receive(:prepare).and_raise(IOError)
    expect(api).to receive(:stop_dyno).with(app: "codecoach", token: "secret", id: "allocated")
    runner = Judge::HerokuDynoRunner.new(app: "codecoach", token: "secret", api: api, rendezvous: rendezvous)
    expect { runner.prepare }.to raise_error(IOError)
  end

  it "bounds output and closes a session even when platform cleanup fails" do
    socket = double("socket", write: 1, close: nil)
    allow(socket).to receive(:readpartial).and_return("x" * 4096)
    closed = 0
    session = Judge::HerokuDynoRunner::Rendezvous::Session.new(socket, on_close: -> { closed += 1; raise IOError })
    expect { session.call(input: "{}", timeout: 1) }.to raise_error(Judge::HerokuDynoRunner::ResponseTooLarge)
    session.close
    expect(closed).to eq(1)
  end
end
