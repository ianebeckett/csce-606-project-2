require "rails_helper"

RSpec.describe ReviewScheduler do
  before { seed_judge }

  let(:user) { create_user }
  let(:problem) { Problem.first }

  it "creates a review schedule from a completed practice rating" do
    # Create a completed practice session with rating 4
    session = user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current,
      completed_at: Time.current,
      status: "completed",
      review_rating: 4
    )

    # Process the completed session
    expect {
      ReviewScheduler.call(session)
    }.to change(ReviewSchedule, :count).by(1)

    # Find the saved review schedule
    schedule = ReviewSchedule.find_by!(
      user: user,
      problem: problem
    )

    expect(schedule.interval_days).to eq(2)
    expect(schedule.next_review_date).to eq(Date.current + 2.days)
  end


  it "rejects an incomplete practice session" do
    # Create a session that is still in progress
    session = user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current,
      status: "in_progress",
      review_rating: 4
    )

    # An incomplete session must not schedule a review
    expect {
      ReviewScheduler.call(session)
    }.to raise_error(ArgumentError)
    expect(ReviewSchedule.count).to eq(0)
  end

  it "rejects a completed session without a rating" do
    # Create a completed session with no performance rating
    session = user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current,
      completed_at: Time.current,
      status: "completed",
      review_rating: nil
    )

    # A rating is required to calculate the review date
    expect {
      ReviewScheduler.call(session)
    }.to raise_error(ArgumentError)
    expect(ReviewSchedule.count).to eq(0)
  end

  it "does not process the same completed session twice" do
    # Create a completed practice session
    session = user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current,
      completed_at: Time.current,
      status: "completed",
      review_rating: 4
    )

    # Process the session for the first time
    schedule = ReviewScheduler.call(session)
    original_interval = schedule.interval_days
    original_date = schedule.next_review_date

    ReviewScheduler.call(session)

    # The schedule should remain unchanged
    schedule.reload
    expect(schedule.interval_days).to eq(original_interval)
    expect(schedule.next_review_date).to eq(original_date)
    expect(ReviewSchedule.where(user: user, problem: problem).count).to eq(1)
  end
end
