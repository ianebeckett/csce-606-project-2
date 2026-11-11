class JudgeSubmissionJob < ApplicationJob
  queue_as :judge

  discard_on ActiveJob::DeserializationError

  def perform(attempt)
    return unless attempt.judge_result == Attempt::PENDING

    attempt.update!(judging_started_at: Time.current)
    Judge::Submission.new.call(attempt)
  rescue StandardError => error
    attempt.update!(judge_result: Attempt::JUDGE_UNAVAILABLE, error_message: Judge::DockerRunner::UNAVAILABLE_MESSAGE)
    Rails.error.report(error)
  end
end
