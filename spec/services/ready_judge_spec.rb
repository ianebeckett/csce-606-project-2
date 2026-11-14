require "rails_helper"
require "open3"

RSpec.describe "Single-use ready judge image" do
  before { seed_judge }

  it "announces readiness before receiving input and executes exactly one payload" do
    problem = Problem.find_by!(slug: "contains-duplicate")
    code = LanguageSolutions::CORRECT.fetch("go").fetch(problem.slug).sub(
      "sort.Ints(nums)", 'if os.Getenv("JUDGE_GO_CACHE") == "" { panic("missing prepared cache") }; sort.Ints(nums)')
    payload = Judge::Payload.build(code: code, language: "go",
      problem: problem, inputs: [ { "args" => [ [ 1, 1 ] ] } ])
    command = [ "docker", "run", "--rm", "--interactive", "--network", "none", "--memory", "512m",
      "--read-only", "--tmpfs", "/tmp:rw,exec,nosuid,size=128m", "--cap-drop", "ALL",
      ENV.fetch("JUDGE_IMAGE", "codecoach-judge:local"), "960s", "ruby", "/judge/ready.rb" ]
    Open3.popen3(*command) do |input, output, errors, process|
      Timeout.timeout(45) do
        expect(output.gets).to eq("CODECOACH_JUDGE_READY\n")
        expect(process.alive?).to be(true)
        input.write(JSON.generate(payload))
        input.close
        expect(JSON.parse(output.read)).to include("status" => "ok", "outputs" => [ true ])
        expect(errors.read).to eq("")
        expect(process.value.success?).to be(true)
      end
    end
  end
end
