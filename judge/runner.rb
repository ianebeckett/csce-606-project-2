require "json"
require "open3"
require "tmpdir"

class Command
  Result = Data.define(:stdout, :stderr, :exit_status, :timed_out, :output_limited)
  OUTPUT_LIMIT = 65_536
  POLL_INTERVAL = 0.02
  READ_CHUNK_SIZE = 4096
  WRITER_JOIN_TIMEOUT = 0.1
  TERMINATION_SIGNAL = "KILL".freeze

  def call(arguments, input: "", timeout:)
    output = +""
    errors = +""
    timed_out = false
    output_limited = false
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    Open3.popen3(*arguments, pgroup: true) do |stdin, stdout, stderr, process|
      writer = Thread.new do
        begin
          stdin.write(input)
        rescue Errno::EPIPE, IOError
        ensure
          stdin.close unless stdin.closed?
        end
      end
      streams = { stdout => output, stderr => errors }
      until streams.empty? && !process.alive?
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if remaining <= 0
          timed_out = true
          break
        end
        ready = IO.select(streams.keys, nil, nil, [ remaining, POLL_INTERVAL ].min)
        next unless ready

        ready.first.each do |stream|
          chunk = stream.read_nonblock(READ_CHUNK_SIZE, exception: false)
          if chunk.nil?
            streams.delete(stream)
          elsif chunk != :wait_readable
            streams.fetch(stream) << chunk
          end
        end
        output_limited = output.bytesize + errors.bytesize > OUTPUT_LIMIT
        break if output_limited
      end
      terminate(process.pid) if timed_out || output_limited
      writer.join(WRITER_JOIN_TIMEOUT)
      writer.kill if writer.alive?
      Result.new(output, errors, process.value.exitstatus, timed_out, output_limited)
    end
  end

  private

  def terminate(pid)
    Process.kill(TERMINATION_SIGNAL, -pid)
  rescue Errno::ESRCH
  end
end

class Submission
  SUCCESS_STATUS = "ok".freeze
  COMPILATION_ERROR = "Compilation Error".freeze
  RUNTIME_ERROR = "Runtime Error".freeze
  TIMEOUT = "Timeout".freeze
  LINKED_LIST_INPUT = "linked_list".freeze
  COMPILE_TIMEOUT = 15
  CASE_TIMEOUT = 4
  MAX_LIST_NODES = 5000

  def initialize(command: Command.new)
    @command = command
  end

  def call(payload)
    language = payload.fetch("language")
    inputs = payload.fetch("inputs")
    outputs = []

    Dir.mktmpdir("codecoach-", "/tmp") do |directory|
      files = prepare(directory, payload)
      compilation = compile(language, files, directory)
      return result(COMPILATION_ERROR, outputs) unless successful?(compilation)

      inputs.each_index do |index|
        execution = @command.call(run_arguments(language, files, index), timeout: CASE_TIMEOUT)
        return result(TIMEOUT, outputs) if execution.timed_out
        return result(RUNTIME_ERROR, outputs) unless successful?(execution)

        outputs << JSON.parse(execution.stdout)
      rescue JSON::ParserError
        return result(RUNTIME_ERROR, outputs)
      end
    end

    result(SUCCESS_STATUS, outputs)
  rescue KeyError, TypeError, ArgumentError, SystemCallError
    result(RUNTIME_ERROR, [])
  end

  private

  def prepare(directory, payload)
    case payload.fetch("language")
    when "ruby" then prepare_ruby(directory, payload)
    when "python" then prepare_python(directory, payload)
    when "go" then prepare_go(directory, payload)
    when "cpp" then prepare_cpp(directory, payload)
    else raise ArgumentError, payload.fetch("language")
    end
  end

  def prepare_ruby(directory, payload)
    source = File.join(directory, "submission.rb")
    wrapper = File.join(directory, "wrapper.rb")
    File.write(source, payload.fetch("code"))
    File.write(wrapper, ruby_wrapper(source, payload))
    { source: source, wrapper: wrapper }
  end

  def prepare_python(directory, payload)
    source = File.join(directory, "submission.py")
    wrapper = File.join(directory, "wrapper.py")
    File.write(source, payload.fetch("code"))
    File.write(wrapper, python_wrapper(source, payload))
    { source: source, wrapper: wrapper }
  end

  def prepare_go(directory, payload)
    source = File.join(directory, "submission.go")
    binary = File.join(directory, "solution")
    File.write(source, go_source(payload))
    { source: source, binary: binary }
  end

  def prepare_cpp(directory, payload)
    source = File.join(directory, "submission.cpp")
    binary = File.join(directory, "solution")
    File.write(source, cpp_source(payload))
    { source: source, binary: binary }
  end

  def compile(language, files, directory)
    arguments = case language
    when "ruby" then [ "ruby", "-c", files.fetch(:source) ]
    when "python" then [ "python3", "-m", "py_compile", files.fetch(:source) ]
    when "go"
      [
        { "GOCACHE" => File.join(directory, "go-cache"), "GOMAXPROCS" => "1", "HOME" => directory },
        "go", "build", "-p=1", "-o", files.fetch(:binary), files.fetch(:source)
      ]
    when "cpp"
      [ "g++", "-std=c++23", "-O0", "-o", files.fetch(:binary), files.fetch(:source) ]
    end
    @command.call(arguments, timeout: COMPILE_TIMEOUT)
  end

  def run_arguments(language, files, index)
    case language
    when "ruby" then [ "ruby", files.fetch(:wrapper), index.to_s ]
    when "python" then [ "python3", files.fetch(:wrapper), index.to_s ]
    else [ files.fetch(:binary), index.to_s ]
    end
  end

  def successful?(execution)
    !execution.timed_out && !execution.output_limited && execution.exit_status == 0
  end

  def result(status, outputs)
    { "status" => status, "outputs" => outputs }
  end

  def method_name(payload)
    words = payload.fetch("method_name").split("_")
    words.first + words.drop(1).map(&:capitalize).join
  end

  def embedded_inputs(payload)
    JSON.generate(JSON.generate(payload.fetch("inputs")))
  end

  def ruby_wrapper(source, payload)
    linked = payload.fetch("input_kind") == LINKED_LIST_INPUT
    <<~RUBY
      require "json"
      require "set"
      require "stringio"

      class ListNode
        attr_accessor :val, :next
        def initialize(val = 0, next_node = nil)
          @val = val
          @next = next_node
        end
      end

      def build_list(values)
        values.reverse_each.reduce(nil) { |following, value| ListNode.new(value, following) }
      end

      def list_values(node)
        values = []
        visited = {}
        while node
          raise TypeError unless node.is_a?(ListNode)
          raise ArgumentError if visited[node.object_id] || values.length >= #{MAX_LIST_NODES}
          visited[node.object_id] = true
          values << node.val
          node = node.next
        end
        values
      end

      inputs = JSON.parse(#{embedded_inputs(payload)})
      arguments = inputs.fetch(Integer(ARGV.fetch(0))).fetch("args")
      arguments[0] = build_list(arguments[0]) if #{linked}
      solution = Object.new
      solution.instance_eval(File.read(#{JSON.generate(source)}), #{JSON.generate(source)})
      original_stdout = $stdout
      $stdout = StringIO.new
      begin
        output = solution.send(#{JSON.generate(payload.fetch("method_name"))}, *arguments)
      ensure
        $stdout = original_stdout
      end
      output = list_values(output) if #{linked}
      puts JSON.generate(output)
    RUBY
  end

  def python_wrapper(source, payload)
    linked = payload.fetch("input_kind") == LINKED_LIST_INPUT
    <<~PYTHON
      import contextlib
      import bisect
      import collections
      import functools
      import heapq
      import io
      import itertools
      import json
      import math
      import re
      import sys
      from collections import Counter, defaultdict, deque
      from typing import List, Optional

      class ListNode:
          def __init__(self, val=0, next_node=None):
              self.val = val
              self.next = next_node

      def build_list(values):
          head = None
          for value in reversed(values):
              head = ListNode(value, head)
          return head

      def list_values(node):
          values = []
          visited = set()
          while node is not None:
              if not isinstance(node, ListNode) or id(node) in visited or len(values) >= #{MAX_LIST_NODES}:
                  raise TypeError()
              visited.add(id(node))
              values.append(node.val)
              node = node.next
          return values

      namespace = {
          "ListNode": ListNode,
          "List": List,
          "Optional": Optional,
          "Counter": Counter,
          "defaultdict": defaultdict,
          "deque": deque,
          "bisect": bisect,
          "collections": collections,
          "functools": functools,
          "heapq": heapq,
          "itertools": itertools,
          "math": math,
          "re": re,
      }
      source_path = #{JSON.generate(source)}
      with open(source_path, encoding="utf-8") as source_file:
          exec(compile(source_file.read(), source_path, "exec"), namespace)
      inputs = json.loads(#{embedded_inputs(payload)})
      arguments = inputs[int(sys.argv[1])]["args"]
      if #{linked ? "True" : "False"}:
          arguments[0] = build_list(arguments[0])
      with contextlib.redirect_stdout(io.StringIO()):
          output = getattr(namespace["Solution"](), #{JSON.generate(method_name(payload))})(*arguments)
      if #{linked ? "True" : "False"}:
          output = list_values(output)
      print(json.dumps(output, separators=(",", ":")))
    PYTHON
  end

  def go_source(payload)
    cases = payload.fetch("inputs").each_with_index.map do |input, index|
      arguments = input.fetch("args").each_with_index.map do |value, argument_index|
        go_argument(value, argument_index, payload)
      end
      output = payload.fetch("output_kind") == "linked_list" ? "listValues(result)" : "result"
      <<~GO
        case #{index}:
          result := #{method_name(payload)}(#{arguments.join(", ")})
          if err := json.NewEncoder(os.Stdout).Encode(#{output}); err != nil {
            os.Exit(1)
          }
      GO
    end.join

    <<~GO
      package main

      import (
        "container/heap"
        "encoding/json"
        "fmt"
        "math"
        "os"
        "sort"
        "strconv"
        "strings"
      )

      #{payload.fetch("code").sub(/\A\s*package\s+main\s*/, "")}

      var (
        _ heap.Interface
        _ = fmt.Print
        _ = math.Abs
        _ = sort.Ints
        _ = strings.Contains
      )

      type ListNode struct {
        Val int
        Next *ListNode
      }

      func buildList(values []int) *ListNode {
        var head *ListNode
        for index := len(values) - 1; index >= 0; index-- {
          head = &ListNode{Val: values[index], Next: head}
        }
        return head
      }

      func listValues(node *ListNode) []int {
        values := []int{}
        visited := map[*ListNode]bool{}
        for node != nil {
          if visited[node] || len(values) >= #{MAX_LIST_NODES} {
            os.Exit(1)
          }
          visited[node] = true
          values = append(values, node.Val)
          node = node.Next
        }
        return values
      }

      func main() {
        index, err := strconv.Atoi(os.Args[1])
        if err != nil {
          os.Exit(1)
        }
        switch index {
      #{cases.rstrip}
        default:
          os.Exit(1)
        }
      }
    GO
  end

  def go_argument(value, index, payload)
    return "buildList(#{go_value(value)})" if payload.fetch("input_kind") == LINKED_LIST_INPUT && index.zero?

    go_value(value)
  end

  def go_value(value)
    case value
    when Array then "[]int{#{value.join(", ")}}"
    when String then JSON.generate(value)
    else value.to_s
    end
  end

  def cpp_source(payload)
    cases = payload.fetch("inputs").each_with_index.map do |input, index|
      declarations = input.fetch("args").each_with_index.map do |value, argument_index|
        cpp_declaration(value, argument_index, payload)
      end
      arguments = input.fetch("args").each_index.map { |argument_index| "argument#{argument_index}" }
      <<~CPP
        case #{index}: {
          #{declarations.join("\n  ")}
          std::ostringstream ignored;
          std::streambuf* original = std::cout.rdbuf(ignored.rdbuf());
          auto output = Solution().#{method_name(payload)}(#{arguments.join(", ")});
          std::cout.rdbuf(original);
          return writeOutput(output) ? 0 : 1;
        }
      CPP
    end.join

    <<~CPP
      #include <bits/stdc++.h>
      using namespace std;

      struct ListNode {
        int val;
        ListNode* next;
        ListNode(int value = 0, ListNode* next_node = nullptr) : val(value), next(next_node) {}
      };

      #{payload.fetch("code")}

      ListNode* buildList(const std::vector<int>& values) {
        ListNode* head = nullptr;
        for (auto iterator = values.rbegin(); iterator != values.rend(); ++iterator) {
          head = new ListNode(*iterator, head);
        }
        return head;
      }

      bool writeOutput(bool output) {
        std::cout << (output ? "true" : "false");
        return true;
      }

      bool writeOutput(int output) {
        std::cout << output;
        return true;
      }

      bool writeOutput(double output) {
        if (!std::isfinite(output)) return false;
        std::cout << std::setprecision(17) << output;
        return true;
      }

      bool writeOutput(ListNode* node) {
        std::vector<int> values;
        std::unordered_set<ListNode*> visited;
        while (node != nullptr) {
          if (visited.contains(node) || values.size() >= #{MAX_LIST_NODES}) return false;
          visited.insert(node);
          values.push_back(node->val);
          node = node->next;
        }
        std::cout << "[";
        for (std::size_t index = 0; index < values.size(); ++index) {
          if (index > 0) std::cout << ",";
          std::cout << values[index];
        }
        std::cout << "]";
        return true;
      }

      int main(int argc, char** argv) {
        if (argc != 2) return 1;
        try {
          int index = std::stoi(argv[1]);
          switch (index) {
      #{cases.rstrip}
          default:
            return 1;
          }
        } catch (...) {
          return 1;
        }
      }
    CPP
  end

  def cpp_declaration(value, index, payload)
    name = "argument#{index}"
    if payload.fetch("input_kind") == LINKED_LIST_INPUT && index.zero?
      "ListNode* #{name} = buildList(#{cpp_vector(value)});"
    elsif value.is_a?(Array)
      "std::vector<int> #{name} = #{cpp_vector(value)};"
    elsif value.is_a?(String)
      "std::string #{name} = #{JSON.generate(value)};"
    else
      "int #{name} = #{value};"
    end
  end

  def cpp_vector(values)
    "std::vector<int>{#{values.join(", ")}}"
  end
end
