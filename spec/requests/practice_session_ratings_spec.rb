require "rails_helper"

RSpec.describe "Practice Session Ratings", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before { seed_judge }

  it "saves a rating and displays the problem when review is due" do
    user = User.create!(
      email: "rating-flow@example.com",
      password: "password12345"
    )
    problem = Problem.find_by!(slug: "contains-duplicate")

    # Create a practice session with an accepted attempt
    practice = user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current
    )

    attempt = practice.attempts.create!(
      code: "def contains_duplicate(nums); false; end",
      language: "ruby",
      judge_result: Attempt::ACCEPTED
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }
    expect(response).to redirect_to(problems_path)

    get attempt_path(attempt)
    expect(response.body).to include("Complete Your Practice")
    patch rate_practice_session_path(practice),
          params: { review_rating: "1", attempt_id: attempt.id }


    expect(response).to redirect_to(problems_path)

    # Verify the rating and completion were saved
    practice.reload
    expect(practice.status).to eq("completed")
    expect(practice.review_rating).to eq(1)
    expect(practice.review_scheduled_at).not_to be_nil

    schedule = ReviewSchedule.find_by!(
      user: user,
      problem: problem
    )

    expect(schedule.interval_days).to eq(1)
    expect(schedule.next_review_date).to eq(Date.tomorrow)

    # Move forward two days so the review is due
    travel_to(2.days.from_now) do
      get problems_path
      expect(response).to have_http_status(:ok)

      dashboard = Nokogiri::HTML(response.body)
      due_reviews = dashboard.at_css(
        "section[aria-labelledby='due-reviews-title']"
      )

      expect(due_reviews).not_to be_nil
      expect(due_reviews.text).to include(problem.title)
    end
  end

  # Shared test data for the security tests
  let(:rating_password) { "password12345" }

  let(:rating_user) do
    User.create!(
      email: "rating-security@example.com",
      password: rating_password
    )
  end

  let(:rating_problem) do
    Problem.find_by!(slug: "contains-duplicate")
  end

  let(:rating_practice) do
    practice = rating_user.practice_sessions.create!(
      problem: rating_problem,
      started_at: Time.current
    )

    practice.attempts.create!(
      code: "puts 1",
      language: "ruby",
      judge_result: Attempt::ACCEPTED
    )
    practice
  end

  it "rejects invalid performance ratings" do
    practice = rating_practice
    post session_path, params: {
      email: rating_user.email,
      password: rating_password
    }

    # Submit a rating outside the allowed range
    patch rate_practice_session_path(practice),
          params: { review_rating: 6 }

    expect(practice.reload.status).to eq("in_progress")
    expect(ReviewSchedule.exists?(
      user: rating_user,
      problem: rating_problem
    )).to be false
  end

  it "prevents students from rating another user's session" do
    practice = rating_practice

    # Create and log in as a different student
    other_user = User.create!(
      email: "another-rating@example.com",
      password: rating_password
    )

    post session_path, params: {
      email: other_user.email,
      password: rating_password
    }

    # Attempt to rate the first student's practice
    patch rate_practice_session_path(practice),
          params: { review_rating: 5 }
    expect(response).to have_http_status(:not_found)
    expect(practice.reload.status).to eq("in_progress")
  end

  it "prevents rating the same attempt twice" do
    practice = rating_practice
    attempt = practice.attempts.last

    # Log in as the student
    post session_path, params: {
      email: rating_user.email,
      password: rating_password
    }
    patch rate_practice_session_path(practice),
          params: { review_rating: 4, attempt_id: attempt.id }

    schedule = ReviewSchedule.find_by!(
      user: rating_user,
      problem: rating_problem
    )

    original_date = schedule.next_review_date
    original_interval = schedule.interval_days

    # Try to submit a second rating
    patch rate_practice_session_path(practice),
          params: { review_rating: 5, attempt_id: attempt.id }

    # The original rating should remain unchanged
    expect(practice.reload.review_rating).to eq(4)
    schedule.reload
    expect(schedule.next_review_date).to eq(original_date)
    expect(schedule.interval_days).to eq(original_interval)
  end


  it "uses the latest attempt rating for review scheduling" do
    practice = rating_practice
    first_attempt = practice.attempts.last

    post session_path, params: {
      email: rating_user.email,
      password: rating_password
    }
    patch rate_practice_session_path(practice),
          params: { review_rating: 2, attempt_id: first_attempt.id }
    expect(practice.reload.review_rating).to eq(2)
    schedule = ReviewSchedule.find_by!(
      user: rating_user,
      problem: rating_problem
    )
    expect(schedule.interval_days).to eq(2)
    travel 1.minute

    second_attempt = practice.attempts.create!(
      code: "puts 2",
      language: "ruby",
      judge_result: Attempt::ACCEPTED
    )

    get attempt_path(first_attempt)
    expect(response.body).not_to include("Complete Your Practice")
    get attempt_path(second_attempt)
    expect(response.body).to include("Complete Your Practice")
    patch rate_practice_session_path(practice),
          params: { review_rating: 5, attempt_id: second_attempt.id }

    expect(practice.reload.review_rating).to eq(5)
    expect(schedule.reload.interval_days).to eq(3)
    expect(schedule.next_review_date).to eq(Date.current + 3.days)

    expect(ReviewSchedule.where(
      user: rating_user,
      problem: rating_problem
    ).count).to eq(1)

    get attempt_path(second_attempt)
    expect(response.body).not_to include("Complete Your Practice")
  end
end
