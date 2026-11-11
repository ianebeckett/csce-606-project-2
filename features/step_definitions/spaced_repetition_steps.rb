World(ActiveSupport::Testing::TimeHelpers)

Given("I completed and rated {string} two days ago") do |title|
  problem = Problem.find_by!(title: title)
  raise "Signed-in user missing" unless @user

  # Simulate the student practicing two days ago
  travel_to(2.days.ago) do
    practice = @user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current
    )

    attempt = practice.attempts.create!(
      code: problem.starter_code,
      language: "ruby",
      judge_result: Attempt::ACCEPTED
    )

    # Open the actual submission results page
    visit attempt_path(attempt)
    select "1 - Very difficult", from: "Your performance rating"

    # Submit the rating using the Rails form
    click_button "Complete Practice"
    expect(page).to have_content("Next review scheduled")

    @review_schedule = ReviewSchedule.find_by!(
      user: @user,
      problem: problem
    )
  end
end

# Verify the problem appears in the Due Reviews section
Then("I see {string} in my due reviews") do |title|
  within("section[aria-labelledby='due-reviews-title']") do
    expect(page).to have_link(title)
  end
end

Then("I see the saved review date") do
  saved_date = @review_schedule.reload.next_review_date
  within("section[aria-labelledby='due-reviews-title']") do
    expect(page).to have_content(
                      saved_date.strftime("%b %d, %Y")
                    )
  end
end



Given("I have three upcoming reviews scheduled") do
  raise "Signed-in user missing" unless @user

  problems = Problem.order(:id).limit(3)
  raise "At least three problems are required" unless problems.size == 3

  @upcoming_reviews = problems.each_with_index.map do |problem, index|
    @user.review_schedules.create!(
      problem: problem,
      next_review_date: Date.current + (index + 1).days,
      interval_days: index + 1
    )
  end
end

Then("I see the two soonest upcoming reviews on the dashboard") do
  within("section[aria-labelledby='upcoming-reviews-title']") do
    @upcoming_reviews.first(2).each do |review|
      expect(page).to have_content(review.problem.title)
    end

    expect(page).not_to have_content(@upcoming_reviews.last.problem.title)
  end
end

Then("I see the dates for those upcoming reviews") do
  within("section[aria-labelledby='upcoming-reviews-title']") do
    @upcoming_reviews.first(2).each do |review|
      expect(page).to have_content(
                        review.next_review_date.strftime("%b %d, %Y")
                      )
    end
  end
end

Then("I can open the full upcoming reviews list") do
  expect(page).to have_link("View all", href: reviews_path)
end

When("I select the upcoming reviews {string} link") do |link_text|
  click_link link_text
end

Then("I see all three upcoming reviews in date order") do
  positions = @upcoming_reviews.map do |review|
    expect(page).to have_content(review.problem.title)
    page.body.index(review.problem.title)
  end

  expect(positions).to eq(positions.sort)
end
