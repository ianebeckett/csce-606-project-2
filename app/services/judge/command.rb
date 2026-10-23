require "open3"

module Judge
  class Command
    Result = Data.define(:stdout, :stderr, :exit_status, :timed_out, :output_limited)
    OUTPUT_LIMIT = 65_536
    DEFAULT_TIMEOUT = 4
    POLL_INTERVAL = 0.02
    READ_CHUNK_SIZE = 4096
    WRITER_JOIN_TIMEOUT = 0.1
    SUCCESS_EXIT_STATUS = 0
    COMMAND_NOT_FOUND = 127
    TERMINATION_SIGNAL = "KILL".freeze

    def call(arguments, input: "", timeout: DEFAULT_TIMEOUT)
      output = +""
      errors = +""
      timed_out = false
      output_limited = false
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      Open3.popen3(*arguments, pgroup: true, close_others: true) do |stdin, stdout, stderr, process|
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
          if streams.empty?
            process.join([ remaining, POLL_INTERVAL ].min)
            next
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
        terminate(process) if timed_out || output_limited
        writer.join(WRITER_JOIN_TIMEOUT)
        writer.kill if writer.alive?
        Result.new(output, errors, process.value.exitstatus, timed_out, output_limited)
      end
    rescue Errno::ENOENT => error
      Result.new("", error.message, COMMAND_NOT_FOUND, false, false)
    end

    private

    def terminate(process)
      [ -process.pid, process.pid ].each do |target|
        next if target.positive? && !process.alive?

        Process.kill(TERMINATION_SIGNAL, target)
      rescue Errno::ESRCH
      end
    end
  end
end
