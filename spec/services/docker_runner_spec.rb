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

  it "distinguishes submission exits from Docker startup failures" do
    [ "exit(1)", "exit!(1)", "exit!(125)", "exit!(126)", "exit!(127)", "at_exit { exit 3 }; true" ].each do |expression|
      result = described_class.new.call(code: "def contains_duplicate(nums); #{expression}; end",
        language: "ruby", problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
      aggregate_failures(expression) do
        expect(result.fetch("status")).to eq("Runtime Error")
      end
    end

    result = described_class.new(image: "codecoach-missing:#{SecureRandom.uuid}").call(
      code: "def contains_duplicate(nums); false; end", language: "ruby", problem: problem,
      inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result.fetch("status")).to eq("Judge Unavailable")
  end

  it "combines parent and child executor coverage" do
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

  it "enforces the non-root identity, memory limit, process limit, and network namespace" do
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

  it "terminates CPU-bound Ruby submissions at the wall-clock deadline" do
    cpu = described_class.new.call(code: "def contains_duplicate(nums); loop {}; end", language: "ruby",
      problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(cpu.fetch("status")).to eq("Timeout")
  end

  it "stops a container at its own wall-clock deadline" do
    result = Judge::Command.new.call(
      [ "docker", "run", "--rm", "--pull=never", image, "0.2s", "ruby", "-e", "loop {}" ],
      timeout: 2
    )

    expect(result.timed_out).to be(false)
    expect(result.exit_status).to eq(128 + Signal.list.fetch("KILL"))
  end

  it "terminates memory-bound Ruby submissions" do
    memory = described_class.new.call(
      code: 'def contains_duplicate(nums); values = []; loop { values << "x" * 8_388_608 }; end',
      language: "ruby", problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(memory.fetch("status")).to eq("Runtime Error")
  end

  it "refuses a write to the read-only judge filesystem" do
    result = described_class.new.call(
      code: 'def contains_duplicate(nums); File.write("/judge/probe", "x"); end', language: "ruby",
      problem: problem, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(result.fetch("status")).to eq("Runtime Error")
  end

  it "reports malformed and cyclic linked-list results without hanging" do
    linked = Problem.find_by!(slug: "reverse-linked-list")
    invalid = described_class.new.call(code: "def reverse_list(head); []; end", language: "ruby",
      problem: linked, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(invalid.fetch("status")).to eq("Runtime Error")
    cyclic = described_class.new.call(code: "def reverse_list(head); head.next = head; head; end", language: "ruby",
      problem: linked, inputs: [ { "args" => [ [ 1 ] ] } ])
    expect(cyclic.fetch("status")).to eq("Runtime Error")
  end

  it "executes the fixed Python, Go, and C++ versions" do
    inputs = problem.test_cases.order(:position).map(&:input)

    %w[python go cpp].each do |language|
      result = described_class.new.call(
        code: LanguageSolutions::CORRECT.fetch(language).fetch(problem.slug), language: language,
        problem: problem, inputs: inputs)
      aggregate_failures(language) do
        expect(result.fetch("status")).to eq("ok")
        expect(result.fetch("outputs")).to eq(problem.test_cases.order(:position).map(&:expected_output))
      end
    end
  end

  it "provides ListNode to Python, Go, and C++ submissions" do
    linked = Problem.find_by!(slug: "reverse-linked-list")
    inputs = linked.test_cases.order(:position).map(&:input)

    %w[python go cpp].each do |language|
      result = described_class.new.call(
        code: LanguageSolutions::CORRECT.fetch(language).fetch(linked.slug), language: language,
        problem: linked, inputs: inputs)
      aggregate_failures(language) do
        expect(result.fetch("status")).to eq("ok")
        expect(result.fetch("outputs")).to eq(linked.test_cases.order(:position).map(&:expected_output))
      end
    end
  end

  it "classifies runtime failures and timeouts in Python, Go, and C++" do
    input = [ problem.test_cases.first.input ]

    %w[python go cpp].each do |language|
      runtime_error = described_class.new.call(
        code: LanguageSolutions::RUNTIME_ERROR.fetch(language), language: language,
        problem: problem, inputs: input)
      timeout = described_class.new.call(
        code: LanguageSolutions::TIMEOUT.fetch(language), language: language,
        problem: problem, inputs: input)

      aggregate_failures(language) do
        expect(runtime_error.fetch("status")).to eq("Runtime Error")
        expect(runtime_error.fetch("outputs")).to be_empty
        expect(timeout.fetch("status")).to eq("Timeout")
        expect(timeout.fetch("outputs")).to be_empty
      end
    end
  end
end
