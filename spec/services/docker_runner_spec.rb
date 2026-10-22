require "rails_helper"

RSpec.describe Judge::DockerRunner do
  before { seed_judge }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:command) { instance_double(Judge::Command) }

  it "restricts the container and always removes only its own container" do
    run_name = nil
    expect(command).to receive(:call) do |arguments, input:, timeout:|
      run_name = arguments[arguments.index("--name") + 1]
      expect(arguments).to include("--read-only")
      expect(arguments.each_cons(2).to_a).to include(
        [ "--network", "none" ], [ "--cap-drop", "ALL" ], [ "--memory", "128m" ],
        [ "--memory-swap", "128m" ], [ "--cpus", "1" ], [ "--pids-limit", "32" ],
        [ "--user", "65534:65534" ], [ "--tmpfs", "/tmp:rw,noexec,nosuid,size=16m" ],
        [ "--ulimit", "nofile=64:64" ], [ "--security-opt", "no-new-privileges" ])
      expect(arguments).not_to include("--privileged", "--volume", "--mount")
      expect(JSON.parse(input)).not_to have_key("expected_output")
      expect(timeout).to eq(4)
      Judge::Command::Result.new('{"status":"ok","output":true}', "", 0, false, false)
    end
    expect(command).to receive(:call) do |arguments, timeout:|
      expect(arguments).to eq([ "docker", "rm", "--force", run_name ])
      Judge::Command::Result.new("", "", 0, false, false)
    end
    result = described_class.new(command: command).call(code: "def contains_duplicate(nums); true; end", problem: problem, input: { "args" => [ [ 1, 1 ] ] })
    expect(result).to eq({ "status" => "ok", "output" => true })
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
        result = described_class.new(command: command).call(code: "test", problem: problem, input: { "args" => [] })
        expect(result.fetch("status")).to eq(verdict)
      end
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
    result = described_class.new.call(code: code, problem: problem, input: { "args" => [ [ 1 ] ] })
    expect(result.fetch("output")).to eq({
      "uid" => 65_534, "memory" => "134217728", "pids" => "32", "routes" => 1,
      "application_present" => false, "secret_present" => false
    })
  end

  it "terminates CPU-bound Ruby submissions at the wall-clock deadline" do
    cpu = described_class.new.call(code: "def contains_duplicate(nums); loop {}; end", problem: problem, input: { "args" => [ [ 1 ] ] })
    expect(cpu.fetch("status")).to eq("Timeout")
  end

  it "stops a container at its own wall-clock deadline" do
    result = Judge::Command.new.call(
      [ "docker", "run", "--rm", "--pull=never", described_class::DEFAULT_IMAGE, "0.2s", "ruby", "-e", "loop {}" ],
      timeout: 2
    )

    expect(result.timed_out).to be(false)
    expect(result.exit_status).to eq(128 + Signal.list.fetch("KILL"))
  end

  it "terminates memory-bound Ruby submissions" do
    memory = described_class.new.call(code: 'def contains_duplicate(nums); values = []; loop { values << "x" * 8_388_608 }; end', problem: problem, input: { "args" => [ [ 1 ] ] })
    expect(memory.fetch("status")).to eq("Runtime Error")
  end

  it "refuses a write to the read-only judge filesystem" do
    result = described_class.new.call(code: 'def contains_duplicate(nums); File.write("/judge/probe", "x"); end', problem: problem, input: { "args" => [ [ 1 ] ] })
    expect(result.fetch("status")).to eq("Runtime Error")
    expect(result.fetch("message")).to match(/Read-only|Permission denied/)
  end

  it "reports malformed and cyclic linked-list results without hanging" do
    linked = Problem.find_by!(slug: "reverse-linked-list")
    invalid = described_class.new.call(code: "def reverse_list(head); []; end", problem: linked, input: { "args" => [ [ 1 ] ] })
    expect(invalid.fetch("status")).to eq("Runtime Error")
    cyclic = described_class.new.call(code: "def reverse_list(head); head.next = head; head; end", problem: linked, input: { "args" => [ [ 1 ] ] })
    expect(cyclic.fetch("status")).to eq("Runtime Error")
    expect(cyclic.fetch("message")).to include("cycle")
  end
end
