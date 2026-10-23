require "coverage"
require "fiddle"
require "json"
require "rbconfig"
require_relative "command"
require_relative "runner"

class RubyJudge
  SET_DUMPABLE = 4
  DUMP_DISABLED = 0
  PRCTL = Fiddle::Function.new(Fiddle::Handle::DEFAULT["prctl"],
    [ Fiddle::TYPE_INT, Fiddle::TYPE_LONG, Fiddle::TYPE_LONG, Fiddle::TYPE_LONG, Fiddle::TYPE_LONG ], Fiddle::TYPE_INT)
  WORKER_PATH = "/judge/execute.rb".freeze
  WORKER_COMMAND = "Coverage.start(lines: true) if ENV['JUDGE_COVERAGE'] == '1'; load '#{WORKER_PATH}'".freeze
  EXECUTION_TIMEOUT = 6
  SUCCESS_STATUS = "ok".freeze
  COMPILATION_ERROR = "Compilation Error".freeze
  RUNTIME_ERROR = "Runtime Error".freeze
  TIMEOUT = "Timeout".freeze
  ERROR_MESSAGE_LIMIT = 1000
  DEFAULT_SIGNALS = %w[HUP INT QUIT TERM ALRM USR1 USR2].freeze
  SYSTEM_DEFAULT_HANDLER = "SYSTEM_DEFAULT".freeze

  def call(payload)
    DEFAULT_SIGNALS.each { |signal| Signal.trap(signal, SYSTEM_DEFAULT_HANDLER) }
    raise SystemCallError.new("Protect judge output", Fiddle.last_error) unless PRCTL.call(SET_DUMPABLE, DUMP_DISABLED, 0, 0, 0).zero?

    RubyVM::InstructionSequence.compile(payload.fetch("code"), RubySubmission::SOURCE_FILENAME)
    execution = Judge::Command.new.call([ RbConfig.ruby, "-rcoverage", "-e", WORKER_COMMAND ], input: JSON.generate(payload), timeout: EXECUTION_TIMEOUT)
    return failure(TIMEOUT, "The Ruby solution exceeded the execution time limit.") if execution.timed_out
    return failure(RUNTIME_ERROR, "The Ruby solution produced too much output.") if execution.output_limited
    unless execution.exit_status == Judge::Command::SUCCESS_EXIT_STATUS
      message = execution.stderr.empty? ? "The Ruby process stopped unexpectedly or exceeded a resource limit." : execution.stderr.strip
      return failure(RUNTIME_ERROR, message)
    end

    value = JSON.parse(execution.stdout)
    result = { "status" => SUCCESS_STATUS, "output" => value.fetch("output") }
    result["coverage"] = value["coverage"] if Coverage.running?
    result
  rescue SyntaxError => error
    failure(COMPILATION_ERROR, error.message)
  rescue JSON::ParserError, KeyError, TypeError, NoMethodError
    failure(RUNTIME_ERROR, "The Ruby solution returned an invalid result.")
  rescue SystemCallError => error
    failure(RUNTIME_ERROR, error.message)
  end

  private

  def failure(status, message)
    { "status" => status, "message" => message[0, ERROR_MESSAGE_LIMIT] }
  end
end

result = RubyJudge.new.call(JSON.parse(STDIN.read))
if Coverage.running?
  child_coverage = result.delete("coverage")
  result["coverage"] = Coverage.result.merge(child_coverage.is_a?(Hash) ? child_coverage : {})
end
puts JSON.generate(result)
