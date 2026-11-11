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
    COMPILE_TIMEOUT = 15
    CASE_TIMEOUT = 4
    CONTAINER_OVERHEAD_TIMEOUT = 5
    CLEANUP_TIMEOUT = 3
    MEMORY_LIMIT_MIB = 512
    CPU_LIMIT = 1
    PROCESS_LIMIT = 32
    NETWORK_MODE = "none".freeze
    DROPPED_CAPABILITIES = "ALL".freeze
    SECURITY_OPTION = "no-new-privileges".freeze
    UNPRIVILEGED_USER = "65534:65534".freeze
    WORK_DIRECTORY = "/tmp".freeze
    TEMPORARY_STORAGE_SIZE = "128m".freeze
    OPEN_FILE_LIMIT = 64
    SUCCESS_STATUS = "ok".freeze
    VALID_STATUSES = [ SUCCESS_STATUS, Attempt::COMPILATION_ERROR, Attempt::RUNTIME_ERROR, Attempt::TIMEOUT ].freeze
    UNAVAILABLE_MESSAGE = "The judge is unavailable. Your code was saved; please try again later.".freeze

    def initialize(command: Command.new, image: ENV.fetch("JUDGE_IMAGE", DEFAULT_IMAGE))
      @command = command
      @image = image
    end

    def call(code:, language:, problem:, inputs:)
      name = "#{CONTAINER_NAME_PREFIX}#{SecureRandom.hex(CONTAINER_NAME_BYTES)}"
      payload = JSON.generate(Payload.build(code: code, language: language, problem: problem, inputs: inputs))
      result = @command.call(arguments(name), input: payload, timeout: execution_timeout(inputs.length))
      return failure(Attempt::TIMEOUT) if result.timed_out
      return failure(Attempt::RUNTIME_ERROR) if result.output_limited
      if UNAVAILABLE_EXIT_STATUSES.include?(result.exit_status)
        return failure(Attempt::JUDGE_UNAVAILABLE)
      end
      return failure(Attempt::RUNTIME_ERROR) unless result.exit_status == Command::SUCCESS_EXIT_STATUS

      parsed = JSON.parse(result.stdout)
      unless parsed.is_a?(Hash) && VALID_STATUSES.include?(parsed["status"]) && parsed.fetch("outputs", []).is_a?(Array)
        return failure(Attempt::RUNTIME_ERROR)
      end
      return failure(Attempt::RUNTIME_ERROR) if parsed.fetch("outputs", []).length > inputs.length

      parsed
    rescue JSON::ParserError
      failure(Attempt::RUNTIME_ERROR)
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
        "--user", UNPRIVILEGED_USER, "--tmpfs", "#{WORK_DIRECTORY}:rw,exec,nosuid,size=#{TEMPORARY_STORAGE_SIZE}",
        "--ulimit", "nofile=#{OPEN_FILE_LIMIT}:#{OPEN_FILE_LIMIT}", "--workdir", WORK_DIRECTORY
      ]
      command.concat([ "--env", "JUDGE_COVERAGE=1" ]) if ENV["JUDGE_COVERAGE"] == "1"
      command << @image
    end

    def execution_timeout(case_count)
      COMPILE_TIMEOUT + (CASE_TIMEOUT * case_count) + CONTAINER_OVERHEAD_TIMEOUT
    end

    def failure(status)
      { "status" => status, "outputs" => [] }
    end
  end
end
