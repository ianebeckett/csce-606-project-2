# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Spaced Repetition Scheduling" do
  before { seed_judge }

  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }
  let(:user) { create_user }

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

  it "creates a review schedule after a successful submission" do

    # Simulate correct answers for all test cases
    problem.test_cases.each do |test_case|
      allow(runner).to receive(:call)
                         .with(
                           code: attempt.code,
                           problem: problem,
                           input: test_case.input
                         )
                         .and_return({
                                       "status" => "ok",
                                       "output" => test_case.expected_output
                                     })
    end

    # Judge the student's submission
    Judge::Submission.new(runner: runner).call(attempt)

    # Find the student's review schedule
    schedule = ReviewSchedule.find_by(
      user: user,
      problem: problem
    )

    # Verify that the schedule exists
    expect(schedule).not_to be_nil

    # First review should be tomorrow
    expect(schedule.next_review_date).to eq(Date.tomorrow)

    # Initial interval should be one day
    expect(schedule.interval_days).to eq(1)
  end



  it "does not create a review schedule after a wrong answer" do
    # Simulate an incorrect answer for every test case
    allow(runner).to receive(:call).and_return({
                                                 "status" => "ok",
                                                 "output" => "incorrect"
                                               })

    # Judge the student's submitted code
    Judge::Submission.new(runner: runner).call(attempt)

    # Verify that the submission was rejected
    expect(attempt.reload.judge_result).to eq(Attempt::WRONG_ANSWER)

    # Verify that no review schedule was created
    expect(
      ReviewSchedule.exists?(user: user, problem: problem)
    ).to be false
  end


  it "does not create duplicate schedules for repeated successful submissions" do
    # Simulate correct answers for every test case
    problem.test_cases.each do |test_case|
      allow(runner).to receive(:call)
                         .with(
                           code: attempt.code,
                           problem: problem,
                           input: test_case.input
                         )
                         .and_return({
                                       "status" => "ok",
                                       "output" => test_case.expected_output
                                     })
    end

    # Judge the student's first successful attempt
    Judge::Submission.new(runner: runner).call(attempt)

    # Create a second attempt for the same problem
    second_attempt = attempt.practice_session.attempts.create!(
      code: attempt.code,
      language: "ruby"
    )

    # Judge the second successful attempt
    Judge::Submission.new(runner: runner).call(second_attempt)

    # Count schedules belonging to this student and problem
    schedule_count = ReviewSchedule.where(
      user: user,
      problem: problem
    ).count

    # Only one review schedule should exist
    expect(schedule_count).to eq(1)

    # Both coding attempts should have been accepted
    expect(attempt.reload.judge_result).to eq(Attempt::ACCEPTED)
    expect(second_attempt.reload.judge_result).to eq(Attempt::ACCEPTED)
  end



end