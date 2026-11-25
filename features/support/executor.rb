require_relative "../../judge/runner"

module ExecutorSteps
  def executor_result(stdout: "", stderr: "", exit_status: 0, timed_out: false, output_limited: false)
    Command::Result.new(stdout, stderr, exit_status, timed_out, output_limited)
  end

  # Run the real payload builder and executor; replace only compiler/process I/O.
  # Strict expectations also reject execution of cases after the first failure.
  def use_scripted_executor(compilation: executor_result, &case_results)
    runner = instance_double(Judge::DockerRunner)
    allow(Judge::Runner).to receive(:build).and_return(runner)
    expect(runner).to receive(:call) do |code:, language:, problem:, inputs:|
      expect(code.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
      expect(language).to eq(@attempt.language)
      expect(inputs).to eq(problem.test_cases.order(:position).map(&:input))

      command = instance_double(Command)
      expect(command).to receive(:call).with(anything, timeout: 15).ordered.and_return(compilation)
      Array(case_results&.call(problem)).each do |result|
        expect(command).to receive(:call).with(anything, timeout: 4).ordered.and_return(result)
      end

      payload = Judge::Payload.build(code: code, language: language, problem: problem, inputs: inputs).deep_stringify_keys
      Submission.new(command: command).call(payload).merge("runtime" => payload.fetch("runtime"))
    end
  end
end

World(ExecutorSteps)
