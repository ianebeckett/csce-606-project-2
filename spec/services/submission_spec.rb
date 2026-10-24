require "rails_helper"

RSpec.describe Judge::Submission do
  before { seed_judge }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:attempt) do
    create_user.practice_sessions.create!(problem: problem, started_at: Time.current).attempts.create!(
      code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby")
  end
  let(:runner) { instance_double(Judge::DockerRunner) }

  it "records blank submissions as Runtime Error without running code" do
    session = create_user.practice_sessions.create!(problem: problem, started_at: Time.current)
    expect(runner).not_to receive(:call)

    [ nil, "", " \t\n" ].each do |code|
      submission = session.attempts.create!(code: code, language: "ruby")
      expect(described_class.new(runner: runner).call(submission)).to equal(submission)
      expect(submission.reload).to have_attributes(
        code: code.to_s, judge_result: "Runtime Error", error_message: "Code can't be blank.",
        passed_cases: 0, total_cases: problem.test_cases.count)
    end
  end

  it "returns the judged Attempt without changing the learning session or submitted code" do
    session = attempt.practice_session
    original_session = session.attributes
    original_code = attempt.code
    problem.test_cases.order(:position).each do |test_case|
      expect(runner).to receive(:call).with(code: attempt.code, problem: problem, input: test_case.input)
        .and_return({ "status" => "ok", "output" => test_case.expected_output })
    end
    result = described_class.new(runner: runner).call(attempt)
    expect(result).to equal(attempt)
    expect(attempt.reload.judge_result).to eq("Accepted")
    expect(attempt.passed_cases).to eq(problem.test_cases.count)
    expect(attempt.code).to eq(original_code)
    expect(session.reload.attributes).to eq(original_session)
  end

  it "counts only correctly answered cases" do
    allow(runner).to receive(:call).and_return({ "status" => "ok", "output" => false })
    described_class.new(runner: runner).call(attempt)
    expect(attempt.reload.judge_result).to eq("Wrong Answer")
    expect(attempt.passed_cases).to eq(problem.test_cases.where(expected_output: false).count)
    expect(attempt.code).to eq(RubySolutions::CORRECT.fetch(problem.slug))
  end

  it "preserves earlier passed cases and returns the Attempt when execution fails" do
    first_output = problem.test_cases.first.expected_output
    allow(runner).to receive(:call).and_return(
      { "status" => "ok", "output" => first_output },
      { "status" => "Runtime Error", "message" => "Execution failed" })
    expect(described_class.new(runner: runner).call(attempt)).to equal(attempt)
    expect(attempt.reload.judge_result).to eq("Runtime Error")
    expect(attempt.error_message).to eq("Execution failed")
    expect(attempt.passed_cases).to eq(1)
  end

  [ Errno::EACCES, ThreadError ].each do |error_class|
    it "saves Judge Unavailable when the runner raises #{error_class}" do
      allow(runner).to receive(:call).and_raise(error_class, "execution unavailable")

      expect(described_class.new(runner: runner).call(attempt)).to equal(attempt)
      expect(attempt.reload.judge_result).to eq("Judge Unavailable")
      expect(attempt.error_message).to eq("The Ruby judge is unavailable. Your code was saved; please try again later.")
      expect(attempt.passed_cases).to eq(0)
      expect(attempt.total_cases).to eq(problem.test_cases.count)
    end
  end

  it "rejects an unfinished problem before execution" do
    problem.test_cases.limit(problem.test_cases.count - 4).destroy_all
    expect(runner).not_to receive(:call)
    expect(described_class.new(runner: runner).call(attempt)).to equal(attempt)
    expect(attempt.reload.judge_result).to eq("Judge Unavailable")
  end

  it "uses the source problem's strict floating-point tolerance" do
    problem = Problem.find_by!(slug: "maximum-average-subarray-i")
    submission = create_user.practice_sessions.create!(problem: problem, started_at: Time.current)
      .attempts.create!(code: "def find_max_average(nums, k); 0; end", language: "ruby")
    problem.test_cases.order(:position).each do |test_case|
      allow(runner).to receive(:call).with(code: submission.code, problem: problem, input: test_case.input)
        .and_return({ "status" => "ok", "output" => test_case.expected_output + 0.000001 })
    end
    described_class.new(runner: runner).call(submission)
    expect(submission.reload.judge_result).to eq("Accepted")
  end
end
