require "json"
require "securerandom"

module Judge
  class DockerRunner
    DOCKER_ERROR = 125
    COMMAND_NOT_EXECUTABLE = 126
    COMMAND_NOT_FOUND = Command::COMMAND_NOT_FOUND
    UNAVAILABLE_EXIT_STATUSES = [ DOCKER_ERROR, COMMAND_NOT_EXECUTABLE, COMMAND_NOT_FOUND ].freeze
    DEFAULT_IMAGE = "codecoach-judge:local".freeze
    CONTAINER_NAME_PREFIX = "codecoach-judge-".freeze
    CONTAINER_NAME_BYTES = 12
    CONTAINER_LABEL = "codecoach.judge=true".freeze
    EXECUTION_TIMEOUT = 4
    CLEANUP_TIMEOUT = 3
    MEMORY_LIMIT_MIB = 128
    CPU_LIMIT = 1
    PROCESS_LIMIT = 32
    NETWORK_MODE = "none".freeze
    DROPPED_CAPABILITIES = "ALL".freeze
    SECURITY_OPTION = "no-new-privileges".freeze
    UNPRIVILEGED_USER = "65534:65534".freeze
    WORK_DIRECTORY = "/tmp".freeze
    TEMPORARY_STORAGE_SIZE = "16m".freeze
    OPEN_FILE_LIMIT = 64
    SUCCESS_STATUS = "ok".freeze
    VALID_STATUSES = [ SUCCESS_STATUS, Attempt::COMPILATION_ERROR, Attempt::RUNTIME_ERROR, Attempt::TIMEOUT ].freeze
    UNAVAILABLE_MESSAGE = "The Ruby judge is unavailable. Your code was saved; please try again later.".freeze

    def initialize(command: Command.new, image: ENV.fetch("JUDGE_IMAGE", DEFAULT_IMAGE))
      @command = command
      @image = image
    end

    def call(code:, problem:, input:)
      name = "#{CONTAINER_NAME_PREFIX}#{SecureRandom.hex(CONTAINER_NAME_BYTES)}"
      payload = JSON.generate(code: code, method_name: problem.method_name, input_kind: problem.input_kind, input: input)
      result = @command.call(arguments(name), input: payload, timeout: EXECUTION_TIMEOUT)
      if result.timed_out
        return { "status" => Attempt::TIMEOUT, "message" => "The Ruby solution exceeded the execution time limit." }
      end
      return failure("The Ruby solution produced too much output.") if result.output_limited
      if UNAVAILABLE_EXIT_STATUSES.include?(result.exit_status)
        return { "status" => Attempt::JUDGE_UNAVAILABLE, "message" => UNAVAILABLE_MESSAGE }
      end
      return failure("The Ruby process stopped unexpectedly or exceeded a resource limit.") unless result.exit_status == Command::SUCCESS_EXIT_STATUS

      parsed = JSON.parse(result.stdout)
      unless parsed.is_a?(Hash) && VALID_STATUSES.include?(parsed["status"])
        return failure("The Ruby solution returned an invalid result.")
      end
      parsed
    rescue JSON::ParserError
      failure("The Ruby solution did not return a readable result.")
    ensure
      @command.call([ "docker", "rm", "--force", name ], timeout: CLEANUP_TIMEOUT) if name
    end

    private

    def arguments(name)
      command = [
        "docker", "run", "--rm", "--pull=never", "--name", name,
        "--label", CONTAINER_LABEL, "--interactive", "--network", NETWORK_MODE,
        "--read-only", "--memory", "#{MEMORY_LIMIT_MIB}m", "--memory-swap", "#{MEMORY_LIMIT_MIB}m", "--cpus", CPU_LIMIT.to_s,
        "--pids-limit", PROCESS_LIMIT.to_s, "--cap-drop", DROPPED_CAPABILITIES, "--security-opt", SECURITY_OPTION,
        "--user", UNPRIVILEGED_USER, "--tmpfs", "#{WORK_DIRECTORY}:rw,noexec,nosuid,size=#{TEMPORARY_STORAGE_SIZE}",
        "--ulimit", "nofile=#{OPEN_FILE_LIMIT}:#{OPEN_FILE_LIMIT}", "--workdir", WORK_DIRECTORY
      ]
      command.concat([ "--env", "JUDGE_COVERAGE=1" ]) if ENV["JUDGE_COVERAGE"] == "1"
      command << @image
    end

    def failure(message)
      { "status" => Attempt::RUNTIME_ERROR, "message" => message }
    end
  end
end
