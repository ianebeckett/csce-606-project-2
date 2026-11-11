require "rails_helper"

RSpec.describe JudgeSubmissionJob do
  before { seed_judge }

  it "records the start before execution and skips redelivery after a verdict is saved" do
    attempt = create_user.practice_sessions.for_today(Problem.first).attempts.create!(code: "saved source")
    submission = instance_double(Judge::Submission)
    allow(Judge::Submission).to receive(:new).and_return(submission)
    expect(submission).to receive(:call).once do |saved|
      expect(saved.reload.judging_started_at).to be_present
      saved.update!(judge_result: "Accepted", total_cases: 6, passed_cases: 6)
    end

    2.times { described_class.perform_now(attempt.reload) }

    expect(attempt.reload.judge_result).to eq("Accepted")
  end

  it "preserves the code and records a job timeout" do
    attempt = create_user.practice_sessions.for_today(Problem.first).attempts.create!(
      code: "saved source", language: "ruby", total_cases: 6)
    submission = instance_double(Judge::Submission)
    error = Delayed::WorkerTimeout.new("job exceeded its deadline")
    allow(Judge::Submission).to receive(:new).and_return(submission)
    allow(submission).to receive(:call).and_raise(error)
    expect(Rails.error).to receive(:report).with(error)

    described_class.perform_now(attempt)

    expect(attempt.reload).to have_attributes(
      code: "saved source", judge_result: "Judge Unavailable", passed_cases: 0, total_cases: 6,
      error_message: "The Ruby judge is unavailable. Your code was saved; please try again later.")
  end
end
