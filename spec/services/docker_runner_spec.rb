require "rails_helper"

RSpec.describe Judge::DockerRunner do
  before { seed_judge }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:command) { instance_double(Judge::Command) }
  let(:image) { ENV.fetch("JUDGE_IMAGE", described_class::DEFAULT_IMAGE) }

  it "restricts the container and always removes only its own container" do
    run_name = nil
    expect(command).to receive(:call) do |arguments, input:, timeout:|
      run_name = arguments[arguments.index("--name") + 1]
      expect(arguments).to include("--read-only")
      expect(arguments.each_cons(2).to_a).to include(
        [ "--network", "none" ], [ "--cap-drop", "ALL" ], [ "--memory", "512m" ],
        [ "--memory-swap", "512m" ], [ "--cpus", "1" ], [ "--pids-limit", "32" ],
        [ "--user", "65534:65534" ], [ "--tmpfs", "/tmp:rw,exec,nosuid,size=128m" ],
        [ "--ulimit", "nofile=64:64" ], [ "--security-opt", "no-new-privileges" ])
      expect(arguments).not_to include("--privileged", "--volume", "--mount")
      payload = JSON.parse(input)
      expect(payload).not_to have_key("expected_output")
      expect(payload).to include("language" => "ruby", "inputs" => [ { "args" => [ [ 1, 1 ] ] } ])
      expect(timeout).to be > 4
      Judge::Command::Result.new(
        '{"status":"ok","outputs":[true],"runtime":"Ruby 4.0.1"}', "", 0, false, false)
    end
    expect(command).to receive(:call) do |arguments, timeout:|
      expect(arguments).to eq([ "docker", "rm", "--force", run_name ])
      Judge::Command::Result.new("", "", 0, false, false)
    end
    result = described_class.new(command: command).call(
      code: "def contains_duplicate(nums); true; end", language: "ruby", problem: problem,
      inputs: [ { "args" => [ [ 1, 1 ] ] } ])
    expect(result).to eq({ "status" => "ok", "outputs" => [ true ], "runtime" => "Ruby 4.0.1" })
  end

  it "classifies unavailable, excessive, and malformed executor output" do
    [
      [ 125, false, "", "Judge Unavailable" ],
      [ 126, false, "", "Judge Unavailable" ],
      [ 127, false, "", "Judge Unavailable" ],
      [ 0, true, "", "Runtime Error" ],
      [ 0, false, "not json", "Runtime Error" ],
      [ 0, false, '{"status":"invented"}', "Runtime Error" ]
    ].each do |exit_status, limited, output, verdict|
      aggregate_failures("exit=#{exit_status}, output=#{output.inspect}, limited=#{limited}") do
        allow(command).to receive(:call).and_return(Judge::Command::Result.new(output, "", exit_status, false, limited))
        result = described_class.new(command: command).call(
          code: "test", language: "ruby", problem: problem, inputs: [ { "args" => [] } ])
        expect(result.fetch("status")).to eq(verdict)
      end
    end
  end

  [ "exit(1)", "exit!(1)", "exit!(125)", "exit!(126)", "exit!(127)", "at_exit { exit 3 }; true" ].each do |expression|
    it "classifies submission #{expression.inspect} as a runtime failure", :docker do
      result = described_class.new.call(code: "def contains_duplicate(nums); #{expression}; end",
        language: "ruby", problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
      expect(result.fetch("status")).to eq("Runtime Error")
    end
  end

  it "reports an unavailable Docker image", :docker do
    result = described_class.new(image: "codecoach-missing:#{SecureRandom.uuid}").call(
      code: "def contains_duplicate(nums); false; end", language: "ruby", problem: problem,
      inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result.fetch("status")).to eq("Judge Unavailable")
  end

  it "combines parent and child executor coverage", :slow do
    payload = JSON.generate(
      code: "def contains_duplicate(nums); true; end",
      method_name: problem.method_name,
      input_kind: problem.input_kind,
      language: "ruby",
      runtime: "Ruby 4.0.1",
      inputs: [ { "args" => [ [ 1, 1 ] ] } ],
      output_kind: "boolean"
    )
    execution = Judge::Command.new.call(
      [ "docker", "run", "--rm", "--pull=never", "--interactive", "--env", "JUDGE_COVERAGE=1",
        image ],
      input: payload, timeout: 4
    )
    report = JSON.parse(execution.stdout).fetch("coverage")

    {
      "/judge/main.rb" => "Submission.new.call",
      "/judge/runner.rb" => "class Submission"
    }.each do |path, source_line|
      line_index = File.readlines(Rails.root.join(path.delete_prefix("/"))).index { |line| line.include?(source_line) }
      expect(line_index).not_to be_nil
      expect(report.fetch(path).fetch("lines").fetch(line_index)).to be_positive
    end
  end

  it "enforces the non-root identity, memory limit, process limit, and network namespace", :docker do
    code = <<~RUBY
      def contains_duplicate(nums)
        {
          "uid" => Process.uid,
          "memory" => File.read("/sys/fs/cgroup/memory.max").strip,
          "pids" => File.read("/sys/fs/cgroup/pids.max").strip,
          "routes" => File.readlines("/proc/net/route").length,
          "application_present" => File.exist?("/rails/config/environment.rb"),
          "secret_present" => ENV.key?("RAILS_MASTER_KEY")
        }
      end
    RUBY
    result = described_class.new.call(
      code: code, language: "ruby", problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result.fetch("outputs").sole).to eq({
      "uid" => 65_534, "memory" => "536870912", "pids" => "32", "routes" => 1,
      "application_present" => false, "secret_present" => false
    })
  end

  it "reports a command timeout and removes its container" do
    run_name = nil
    expect(command).to receive(:call) do |arguments, input:, timeout:|
      run_name = arguments[arguments.index("--name") + 1]
      expect(JSON.parse(input).fetch("code")).to include("loop {}")
      expect(timeout).to eq(24)
      Judge::Command::Result.new("", "", nil, true, false)
    end
    expect(command).to receive(:call) do |arguments, timeout:|
      expect(arguments).to eq([ "docker", "rm", "--force", run_name ])
      expect(timeout).to eq(3)
      Judge::Command::Result.new("", "", 0, false, false)
    end

    result = described_class.new(command: command).call(code: "def contains_duplicate(nums); loop {}; end", language: "ruby",
      problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result).to eq("status" => "Timeout", "outputs" => [])
  end

  it "stops a container at its own wall-clock deadline", :slow do
    result = Judge::Command.new.call(
      [ "docker", "run", "--rm", "--pull=never", image, "0.2s", "ruby", "-e", "loop {}" ],
      timeout: 2
    )

    expect(result.timed_out).to be(false)
    expect(result.exit_status).to eq(128 + Signal.list.fetch("KILL"))
  end

  it "terminates memory-bound Ruby submissions", :docker do
    memory = described_class.new.call(
      code: 'def contains_duplicate(nums); values = []; loop { values << "x" * 8_388_608 }; end',
      language: "ruby", problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(memory.fetch("status")).to eq("Runtime Error")
  end

  it "refuses a write to the read-only judge filesystem", :docker do
    result = described_class.new.call(
      code: 'def contains_duplicate(nums); File.write("/judge/probe", "x"); end', language: "ruby",
      problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result.fetch("status")).to eq("Runtime Error")
  end

  it "reports malformed and cyclic linked-list results without hanging", :docker do
    linked = Problem.find_by!(slug: "reverse-linked-list")
    invalid = described_class.new.call(code: "def reverse_list(head); []; end", language: "ruby",
      problem: linked, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(invalid.fetch("status")).to eq("Runtime Error")
    cyclic = described_class.new.call(code: "def reverse_list(head); head.next = head; head; end", language: "ruby",
      problem: linked, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(cyclic.fetch("status")).to eq("Runtime Error")
  end

  %w[python go cpp].each do |language|
    %w[contains-duplicate reverse-linked-list].each do |slug|
      it "passes #{language} #{slug} to the executor and returns its results" do
        problem = Problem.find_by!(slug: slug)
        cases = problem.test_cases.order(:position)
        inputs = cases.map(&:input)
        code = LanguageSolutions::CORRECT.fetch(language).fetch(slug)
        response = { "status" => "ok", "outputs" => cases.map(&:expected_output),
                     "runtime" => Attempt.language_version(language) }
        expect(command).to receive(:call) do |arguments, input:, timeout:|
          expect(arguments.first(2)).to eq([ "docker", "run" ])
          expect(JSON.parse(input)).to include(
            "code" => code, "language" => language, "inputs" => inputs,
            "method_name" => problem.method_name, "input_kind" => problem.input_kind,
            "runtime" => Attempt.language_version(language))
          Judge::Command::Result.new(JSON.generate(response), "", 0, false, false)
        end
        expect(command).to receive(:call).with(
          [ "docker", "rm", "--force", start_with("codecoach-judge-") ], timeout: 3)

        expect(described_class.new(command: command).call(
          code: code, language: language, problem: problem, inputs: inputs)).to eq(response)
      end
    end
  end
end
