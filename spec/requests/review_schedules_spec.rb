
require "rails_helper"

RSpec.describe "Review Schedules", type: :request do
  it "requires a user to be logged in" do
    get reviews_path
    expect(response).to redirect_to(new_session_path)
  end

  it "shows a message when the student has no upcoming reviews" do
    user = User.create!(
      email: "reviews-test@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get reviews_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Upcoming Reviews")
    expect(response.body).to include("You don't have any upcoming reviews scheduled")
  end

  it "only displays upcoming reviews belonging to the logged-in student" do
    seed_judge

    user = User.create!(
      email: "my-review@example.com",
      password: "password12345"
    )

    other_user = User.create!(
      email: "other-review@example.com",
      password: "password12345"
    )

    my_problem = Problem.first
    other_problem = Problem.second

    ReviewSchedule.create!(
      user: user,
      problem: my_problem,
      next_review_date: Date.current + 2.days,
      interval_days: 2
    )

    ReviewSchedule.create!(
      user: other_user,
      problem: other_problem,
      next_review_date: Date.current + 3.days,
      interval_days: 3
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get reviews_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(my_problem.title)
    expect(response.body).not_to include(other_problem.title)
  end

  it "displays upcoming reviews in date order and excludes due reviews" do
    seed_judge

    user = User.create!(
      email: "future-review@example.com",
      password: "password12345"
    )

    due_problem = Problem.first
    later_problem = Problem.second
    sooner_problem = Problem.third

    ReviewSchedule.create!(
      user: user,
      problem: due_problem,
      next_review_date: Date.current,
      interval_days: 1
    )

    ReviewSchedule.create!(
      user: user,
      problem: later_problem,
      next_review_date: Date.current + 7.days,
      interval_days: 7
    )

    ReviewSchedule.create!(
      user: user,
      problem: sooner_problem,
      next_review_date: Date.current + 2.days,
      interval_days: 2
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get reviews_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(due_problem.title)
    expect(response.body).to include(sooner_problem.title)
    expect(response.body).to include(later_problem.title)

    expect(response.body.index(sooner_problem.title))
      .to be < response.body.index(later_problem.title)
  end
end
