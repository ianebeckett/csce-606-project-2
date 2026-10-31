require "rails_helper"

RSpec.describe "Spaced Repetition Scheduling" do
  before { seed_judge }

  let(:user) { create_user }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  let(:attempt) do
    user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current
    ).attempts.create!(
      code: RubySolutions::CORRECT.fetch(problem.slug),
      language: "ruby"
    )
  end

  let(:runner) { instance_double(Judge::DockerRunner) }

  it "does not create a review schedule from an accepted submission" do
    # Simulate a successful coding submission
    problem.test_cases.each do |test_case|
      allow(runner).to receive(:call)
                         .with(code: attempt.code, problem: problem, input: test_case.input)
                         .and_return({
                                       "status" => "ok",
                                       "output" => test_case.expected_output
                                     })
    end

    # Judge the submitted code
    Judge::Submission.new(runner: runner).call(attempt)
    expect(attempt.reload.judge_result).to eq(Attempt::ACCEPTED)
    expect(ReviewSchedule.exists?(user: user, problem: problem)).to be false
  end

  it "does not change an existing schedule after a wrong answer" do
    # Create a schedule previously calculated from a rating
    schedule = ReviewSchedule.create!(
      user: user,
      problem: problem,
      interval_days: 4,
      next_review_date: Date.current + 4.days
    )

    # Simulate an incorrect submission
    allow(runner).to receive(:call).and_return({
                                                 "status" => "ok",
                                                 "output" => "incorrect"
                                               })
    Judge::Submission.new(runner: runner).call(attempt)
    expect(attempt.reload.judge_result).to eq(Attempt::WRONG_ANSWER)

    # The existing review schedule should remain unchanged
    schedule.reload
    expect(schedule.interval_days).to eq(4)
    expect(schedule.next_review_date).to eq(Date.current + 4.days)
  end
end
