require "rails_helper"
require_relative "../../judge/runner"

# Exercise the actual executor without compiling programs or waiting on clocks.
# Integration specs retain real language execution; Docker specs check isolation.
RSpec.describe Submission do
  let(:command) { instance_double(Command) }
  let(:executor) { described_class.new(command: command) }
  let(:success) { Command::Result.new("true", "", 0, false, false) }
  let(:payload) do
    problem = Problem.find_by!(slug: "contains-duplicate")
    Judge::Payload.build(code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby", problem: problem,
      inputs: [ { "args" => [ [ 1, 1 ] ] }, { "args" => [ [ 2, 2 ] ] }, { "args" => [ [ 3, 3 ] ] } ]).deep_stringify_keys
  end

  %w[ruby python go cpp].each do |language|
    context "with #{language}" do
      let(:payload) do
        problem = Problem.find_by!(slug: "contains-duplicate")
        code = language == "ruby" ? RubySolutions::CORRECT.fetch(problem.slug) : LanguageSolutions::CORRECT.fetch(language).fetch(problem.slug)
        Judge::Payload.build(code: code, language: language, problem: problem,
          inputs: [ { "args" => [ [ 1, 1 ] ] }, { "args" => [ [ 2, 2 ] ] }, { "args" => [ [ 3, 3 ] ] } ]).deep_stringify_keys
      end

      it "parses outputs in case order and removes temporary files" do
        directory = nil
        expect(command).to receive(:call).with(anything, timeout: 15).ordered do |arguments, timeout:|
          directory = File.dirname(arguments.last)
          expect(File.file?(arguments.last)).to be(true)
          success
        end
        [ true, false, true ].each_with_index do |output, index|
          expect(command).to receive(:call).with(anything, timeout: 4).ordered do |arguments, timeout:|
            expect(arguments.last).to eq(index.to_s)
            Command::Result.new(JSON.generate(output), "", 0, false, false)
          end
        end

        expect(executor.call(payload)).to eq("status" => "ok", "outputs" => [ true, false, true ])
        expect(File.exist?(directory)).to be(false)
      end

      it "generates linked-list input and output adapters" do
        linked = Problem.find_by!(slug: "reverse-linked-list")
        code = language == "ruby" ? RubySolutions::CORRECT.fetch(linked.slug) : LanguageSolutions::CORRECT.fetch(language).fetch(linked.slug)
        linked_payload = Judge::Payload.build(code: code, language: language, problem: linked,
          inputs: [ { "args" => [ [ 1, 2 ] ] } ]).deep_stringify_keys
        expect(command).to receive(:call).with(anything, timeout: 15).ordered do |arguments, timeout:|
          directory = File.dirname(arguments.last)
          wrapper = case language
          when "ruby" then File.join(directory, "wrapper.rb")
          when "python" then File.join(directory, "wrapper.py")
          else arguments.last
          end
          source = File.read(wrapper)
          expect(source).to include("ListNode")
          case language
          when "ruby"
            expect(source).to include("build_list(arguments[0]) if true", "list_values(output) if true")
          when "python"
            expect(source).to include("if True:\n    arguments[0] = build_list(arguments[0])", "output = list_values(output)")
          when "go"
            expect(source).to include("reverseList(buildList([]int{1, 2}))", "Encode(listValues(result))")
          when "cpp"
            expect(source).to include("ListNode* argument0 = buildList(std::vector<int>{1, 2});",
              "bool writeOutput(ListNode* node)", "writeOutput(output)")
          end
          success
        end
        expect(command).to receive(:call).with(anything, timeout: 4).ordered
          .and_return(Command::Result.new("[2,1]", "", 0, false, false))

        expect(executor.call(linked_payload)).to eq("status" => "ok", "outputs" => [ [ 2, 1 ] ])
      end

      it "stops after a compilation failure without running any cases" do
        expect(command).to receive(:call).once.with(anything, timeout: 15)
          .and_return(Command::Result.new("", "syntax error", 1, false, false))

        expect(executor.call(payload)).to eq("status" => "Compilation Error", "outputs" => [])
      end

      it "reports a timeout while preserving earlier outputs and skipping later cases" do
        payload["code"] = language == "ruby" ? "def contains_duplicate(nums); loop {}; end" : LanguageSolutions::TIMEOUT.fetch(language)
        expect(command).to receive(:call).with(anything, timeout: 15).ordered.and_return(success)
        expect(command).to receive(:call).with(anything, timeout: 4).ordered.and_return(success)
        expect(command).to receive(:call).with(anything, timeout: 4).ordered
          .and_return(Command::Result.new("", "", nil, true, false))

        expect(executor.call(payload)).to eq("status" => "Timeout", "outputs" => [ true ])
      end

      it "reports a runtime failure while preserving earlier outputs and skipping later cases" do
        expect(command).to receive(:call).with(anything, timeout: 15).ordered.and_return(success)
        expect(command).to receive(:call).with(anything, timeout: 4).ordered.and_return(success)
        expect(command).to receive(:call).with(anything, timeout: 4).ordered
          .and_return(Command::Result.new("", "private stack trace", 1, false, false))

        expect(executor.call(payload)).to eq("status" => "Runtime Error", "outputs" => [ true ])
      end
    end
  end

  it "preserves earlier outputs and stops when a case emits malformed JSON" do
    expect(command).to receive(:call).with(anything, timeout: 15).ordered.and_return(success)
    expect(command).to receive(:call).with(anything, timeout: 4).ordered.and_return(success)
    expect(command).to receive(:call).with(anything, timeout: 4).ordered
      .and_return(Command::Result.new("not json", "", 0, false, false))

    expect(executor.call(payload)).to eq("status" => "Runtime Error", "outputs" => [ true ])
  end

  it "rejects truncated output even when the process exits successfully" do
    expect(command).to receive(:call).with(anything, timeout: 15).ordered.and_return(success)
    expect(command).to receive(:call).with(anything, timeout: 4).ordered
      .and_return(Command::Result.new("true", "", 0, false, true))

    expect(executor.call(payload)).to eq("status" => "Runtime Error", "outputs" => [])
  end

  it "rejects an unsupported executor language before invoking a command" do
    payload["language"] = "javascript"
    expect(command).not_to receive(:call)

    expect(executor.call(payload)).to eq("status" => "Runtime Error", "outputs" => [])
  end

  it "rejects an incomplete payload before invoking a command" do
    payload.delete("method_name")
    expect(command).not_to receive(:call)

    expect(executor.call(payload)).to eq("status" => "Runtime Error", "outputs" => [])
  end

  %w[go cpp].each do |language|
    it "encodes string, scalar, and array arguments for #{language}" do
      text = "quoted \"text\"\nnext"
      code = if language == "go"
        "func checkValues(text string, count int, nums []int) bool { return true }"
      else
        "class Solution { public: bool checkValues(string text, int count, vector<int> nums) { return true; } };"
      end
      payload.merge!("language" => language, "method_name" => "check_values", "code" => code,
        "inputs" => [ { "args" => [ text, 3, [ 1, 2 ] ] } ])
      expect(command).to receive(:call).with(anything, timeout: 15).ordered do |arguments, timeout:|
        source = File.read(arguments.last)
        if language == "go"
          expect(source).to include("checkValues(#{JSON.generate(text)}, 3, []int{1, 2})")
        else
          expect(source).to include("std::string argument0 = #{JSON.generate(text)};", "int argument1 = 3;",
            "std::vector<int> argument2 = std::vector<int>{1, 2};", "checkValues(argument0, argument1, argument2)")
        end
        success
      end
      expect(command).to receive(:call).with(anything, timeout: 4).ordered.and_return(success)

      expect(executor.call(payload)).to eq("status" => "ok", "outputs" => [ true ])
    end
  end
end
