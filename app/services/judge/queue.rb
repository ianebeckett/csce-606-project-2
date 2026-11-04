module Judge
  class Queue
    MAX_PENDING = Integer(ENV.fetch("JUDGE_QUEUE_LIMIT", "10"), 10)
    raise ArgumentError, "JUDGE_QUEUE_LIMIT must be positive" unless MAX_PENDING.positive?

    class Full < StandardError
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = retry_after
        super("The judge is at capacity (#{MAX_PENDING} pending submissions). " \
          "Please try again in about #{retry_after} seconds. " \
          "Your code is still in the editor; this submission was not queued. " \
          "This is an estimate; delays or retries can take longer.")
      end
    end

    def submit(attempt)
      return false unless attempt.valid?

      Attempt.transaction do
        pending = pending_attempts.limit(MAX_PENDING).to_a
        if pending.size >= MAX_PENDING
          first = pending.find(&:judging_started_at) || pending.first
          raise Full, (remaining_seconds(first) + Delayed::Worker.sleep_delay).ceil
        end

        attempt.save!
        enqueue(attempt)
        true
      end
    end

    def wait_for(attempt)
      ahead = pending_attempts.where("id < :id OR (id != :id AND judging_started_at IS NOT NULL)", id: attempt.id).to_a
      { count: ahead.size, seconds: (ahead.sum { |pending| remaining_seconds(pending) } + Delayed::Worker.sleep_delay).ceil }
    end

    private

    def pending_attempts
      Attempt.where(judge_result: Attempt::PENDING).order(:id)
    end

    def remaining_seconds(attempt)
      budget = [ attempt.total_cases, Problem::MINIMUM_TEST_CASES ].max * (DockerRunner::EXECUTION_TIMEOUT + DockerRunner::CLEANUP_TIMEOUT)
      elapsed = attempt.judging_started_at ? [ Time.current - attempt.judging_started_at, 0 ].max : 0
      [ budget - elapsed, Delayed::Worker.sleep_delay ].max
    end

    def enqueue(attempt)
      begin
        enqueued = JudgeSubmissionJob.perform_later(attempt)
      rescue ActiveRecord::ActiveRecordError => error
        Rails.error.report(error)
      end
      unless enqueued
        attempt.update!(judge_result: Attempt::JUDGE_UNAVAILABLE, error_message: DockerRunner::UNAVAILABLE_MESSAGE)
      end
    end
  end
end
