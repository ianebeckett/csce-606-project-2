require "rails_helper"

RSpec.describe JudgeSubmissionJob do
  before { seed_judge }

  it "retries database errors when loading an attempt but discards a deleted attempt" do
    attempt = create_user.practice_sessions.for_today(Problem.first).attempts.create!(code: "saved source", language: "ruby")
    job = described_class.new(attempt)
    ActiveJob::QueueAdapters.lookup(:delayed_job).new.enqueue(job)
    queued = Delayed::Job.find(job.provider_job_id)
    worker = Delayed::Worker.new(queues: [ "judge" ])
    allow(GlobalID::Locator).to receive(:locate).and_raise(ActiveRecord::ConnectionNotEstablished, "database unavailable")

    expect(worker.work_off(1)).to eq([ 0, 1 ])
    expect(queued.reload.attempts).to eq(1)
    expect(attempt.reload.judge_result).to eq("Pending")

    allow(GlobalID::Locator).to receive(:locate).and_call_original
    attempt.destroy!
    queued.update!(run_at: Time.current)
    expect(worker.work_off(1)).to eq([ 1, 0 ])
    expect(Delayed::Job.exists?(queued.id)).to be(false)
  end

  it "preserves the code and records an unexpected job failure" do
    attempt = create_user.practice_sessions.for_today(Problem.first).attempts.create!(
      code: "saved source", language: "ruby", total_cases: 6)
    submission = instance_double(Judge::Submission)
    error = RuntimeError.new("unexpected judge failure")
    allow(Judge::Submission).to receive(:new).and_return(submission)
    allow(submission).to receive(:call).and_raise(error)
    expect(Rails.error).to receive(:report).with(error)

    described_class.perform_now(attempt)

    expect(attempt.reload).to have_attributes(
      code: "saved source", judge_result: "Judge Unavailable", passed_cases: 0, total_cases: 6,
      error_message: "The Ruby judge is unavailable. Your code was saved; please try again later.")
  end
end
