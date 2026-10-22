require "rails_helper"
require "rbconfig"

RSpec.describe Judge::Command do
  it "captures a child process without invoking a shell" do
    result = described_class.new.call([ RbConfig.ruby, "-e", 'print STDIN.read; warn "diagnostic"' ], input: "literal $(echo test)")
    expect(result.stdout).to eq("literal $(echo test)")
    expect(result.stderr).to include("diagnostic")
    expect(result.exit_status).to eq(0)
  end

  it "terminates an owned process group at its deadline" do
    result = described_class.new.call([ RbConfig.ruby, "-e", "sleep 10" ], timeout: 0.15)
    expect(result.timed_out).to be(true)
  end

  it "limits unbounded output" do
    result = described_class.new.call([ RbConfig.ruby, "-e", 'STDOUT.sync = true; loop { print "x" * 4096 }' ])
    expect(result.output_limited).to be(true)
    expect(result.stdout.bytesize).to be < 100_000
  end

  it "reports a missing executable instead of crashing" do
    result = described_class.new.call([ "/codecoach/nonexistent-command" ])
    expect(result.exit_status).to eq(127)
  end
end
