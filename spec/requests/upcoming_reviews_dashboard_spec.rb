
require "rails_helper"

RSpec.describe "Upcoming Reviews Dashboard", type: :request do
  it "displays the two soonest reviews and links to all reviews" do
    seed_judge

    user = User.create!(
      email: "dashboard-test@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    first_problem = Problem.first
    second_problem = Problem.second
    third_problem = Problem.third

    ReviewSchedule.create!(
      user: user,
      problem: first_problem,
      next_review_date: Date.current + 1.day,
      interval_days: 1
    )

    ReviewSchedule.create!(
      user: user,
      problem: second_problem,
      next_review_date: Date.current + 2.days,
      interval_days: 2
    )

    ReviewSchedule.create!(
      user: user,
      problem: third_problem,
      next_review_date: Date.current + 3.days,
      interval_days: 3
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get problems_path

    expect(response).to have_http_status(:ok)

    card = Nokogiri::HTML(response.body).at_css(".upcoming-reviews-card")

    expect(card).not_to be_nil
    expect(card["href"]).to eq(reviews_path)

    review_items = card.css(".upcoming-review-item")

    expect(review_items.size).to eq(2)
    expect(review_items[0].text).to include(first_problem.title)
    expect(review_items[1].text).to include(second_problem.title)
  end

  it "only displays the logged-in student's upcoming reviews" do
    seed_judge

    user = User.create!(
      email: "dashboard-user@example.com",
      password: "password12345",
      password_confirmation: "password12345"
    )

    other_user = User.create!(
      email: "dashboard-other@example.com",
      password: "password12345",
      password_confirmation: "password12345"
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
      next_review_date: Date.current + 2.days,
      interval_days: 2
    )

    post session_path, params: {
      email: user.email,
      password: "password12345"
    }

    get problems_path

    card = Nokogiri::HTML(response.body).at_css(".upcoming-reviews-card")

    expect(card.text).to include(my_problem.title)
    expect(card.text).not_to include(other_problem.title)
  end
end
