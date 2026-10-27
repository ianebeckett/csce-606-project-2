require "rails_helper"

RSpec.describe "Review Schedules", type: :request do
  it "requires a user to be logged in" do
    get reviews_path
    expect(response).to redirect_to(new_session_path)
  end


  it "shows a message when the student has no reviews due" do
    # Create a student account for testing
    user = User.create!(
      email: "reviews-test@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    expect(response).to redirect_to(problems_path)

    get reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Problems Due for Review")
    expect(response.body).to include("No problems are due for review")
  end


  it "only displays reviews belonging to the logged-in student" do
    seed_judge
    user = User.create!(
      email: "my-review@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    other_user = User.create!(
      email: "other-review@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    # Select two different coding problems
    my_problem = Problem.first
    other_problem = Problem.second

    ReviewSchedule.create!(
      user: user,
      problem: my_problem,
      next_review_date: Date.current,
      interval_days: 1
    )

    ReviewSchedule.create!(
      user: other_user,
      problem: other_problem,
      next_review_date: Date.current,
      interval_days: 1
    )

    # Log in as the first student
    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    expect(response).to redirect_to(problems_path)
    get reviews_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(my_problem.title)
    expect(response.body).not_to include(other_problem.title)
  end


  it "does not display problems scheduled for future reviews" do
    seed_judge

    user = User.create!(
      email: "future-review@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    due_problem = Problem.first
    future_problem = Problem.second

    ReviewSchedule.create!(
      user: user,
      problem: due_problem,
      next_review_date: Date.current,
      interval_days: 1
    )

    # Create a review scheduled for next week
    ReviewSchedule.create!(
      user: user,
      problem: future_problem,
      next_review_date: Date.current + 7.days,
      interval_days: 7
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(due_problem.title)
    expect(response.body).not_to include(future_problem.title)
  end
end
