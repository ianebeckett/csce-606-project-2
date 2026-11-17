require_relative "../../test_support/heroku_judge_stub"

def prepare_heroku_pool(result)
  @heroku_stub = HerokuJudgeStub.new(result: result)
  @ready_pool = Judge::HerokuPool.new(size: 2, factory: -> { @heroku_stub.runner.prepare })
  @ready_pool.start
  Timeout.timeout(2) { sleep 0.005 until @ready_pool.ready_count == 2 }
  runner = Judge::HerokuDynoRunner.new(app: "codecoach", token: "test-secret", pool: @ready_pool)
  @original_judge_runner_build = Judge::Runner.method(:build)
  Judge::Runner.define_singleton_method(:build) { runner }
end

Given("two unused Heroku judges are ready") do
  problem = Problem.find_by!(slug: "contains-duplicate")
  prepare_heroku_pool(JSON.generate(status: "ok", runtime: "Ruby 4.0.1",
    outputs: problem.test_cases.order(:position).map(&:expected_output)))
end

Given("a ready Heroku judge will return an invalid result") { prepare_heroku_pool("invalid JSON") }

Then("my judge is retired and two unused judges become ready") do
  expect(@heroku_stub.stopped.size).to eq(1)
  Timeout.timeout(2) { sleep 0.005 until @ready_pool.ready_count == 2 }
  expect(@heroku_stub.requests.size).to eq(3)
  expect(@heroku_stub.payloads.size).to eq(1)
end

After do
  @ready_pool&.stop
  @heroku_stub&.close
end
