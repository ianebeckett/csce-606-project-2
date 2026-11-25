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
    choose "review_rating_1"

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
  expect(page).to have_link("View All", href: reviews_path)
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

Given("I have a completed coding attempt with a {int}-day review interval") do |interval|
  travel_to(Time.current.change(usec: 0))
  problem = Problem.find_by!(slug: "contains-duplicate")
  @rating_practice = @user.practice_sessions.for_today(problem)
  @rating_attempt = @rating_practice.attempts.create!(
    code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby", judge_result: Attempt::ACCEPTED,
    passed_cases: problem.test_cases.count, total_cases: problem.test_cases.count)
  @rating_schedule = @user.review_schedules.create!(
    problem: problem, interval_days: interval, next_review_date: Date.current + interval.days)
end

When("I rate that practice {int}") do |rating|
  @selected_rating = rating
  visit attempt_path(@rating_attempt)
  choose "review_rating_#{rating}"
  click_button "Complete Practice"
end

Then("my next review is scheduled in {int} days") do |days|
  expect(page).to have_content("Next review scheduled for #{Date.current + days.days}.")
  expect(@rating_schedule.reload).to have_attributes(
    interval_days: days, next_review_date: Date.current + days.days, scheduled_for: Date.current + days.days)
  expect(@user.review_schedules.count).to eq(1)
end

Then("my completed practice records that rating") do
  expect(@rating_practice.reload).to have_attributes(
    status: "completed", review_rating: @selected_rating, completed_at: Time.current, review_scheduled_at: Time.current)
end

When("I try to rate that practice with {string}") do |request|
  rating = 5
  case request
  when "an invalid rating"
    rating = 6
  when "an older attempt"
    @rating_practice.attempts.create!(
      code: @rating_attempt.code, language: "ruby", judge_result: Attempt::ACCEPTED,
      passed_cases: @rating_attempt.passed_cases, total_cases: @rating_attempt.total_cases)
  when "an unfinished attempt"
    @rating_attempt.update!(judge_result: Attempt::PENDING, passed_cases: 0)
  when "an already rated attempt"
    visit attempt_path(@rating_attempt)
    choose "review_rating_4"
    click_button "Complete Practice"
    expect(page).to have_content("Next review scheduled")
  else
    raise ArgumentError, request
  end

  @practice_before_rating = @rating_practice.reload.attributes
  @schedule_before_rating = @rating_schedule.reload.attributes
  page.driver.submit(:patch, rate_practice_session_path(@rating_practice),
    { review_rating: rating, attempt_id: @rating_attempt.id })
end

Then("I see the rating rejection {string}") do |message|
  expect(page).to have_current_path(problems_path)
  expect(page).to have_content(message)
end

Then("my practice and review schedule are unchanged") do
  expect(@rating_practice.reload.attributes).to eq(@practice_before_rating)
  expect(@rating_schedule.reload.attributes).to eq(@schedule_before_rating)
  expect(@user.review_schedules.count).to eq(1)
end

Given("I have overdue, due-today, future, and another member's reviews") do
  travel_to(Time.current.change(usec: 0))
  problems = Problem.order(:id).limit(4).to_a
  @future_review = @user.review_schedules.create!(
    problem: problems[0], interval_days: 1, next_review_date: Date.tomorrow)
  @today_review = @user.review_schedules.create!(
    problem: problems[1], interval_days: 1, next_review_date: Date.current)
  @overdue_review = @user.review_schedules.create!(
    problem: problems[2], interval_days: 1, next_review_date: Date.yesterday)
  other = create_user(email: "other-reviewer@example.com")
  @other_review = other.review_schedules.create!(
    problem: problems[3], interval_days: 1, next_review_date: Date.yesterday)
end

When("I open the due reviews page") { visit due_reviews_path }

Then("I see only my overdue and due-today reviews in date order") do
  titles = page.all("tbody tr").map { |row| row.all("td").first.text.strip }
  expect(titles).to eq([ @overdue_review.problem.title, @today_review.problem.title ])
  expect(page).not_to have_content(@future_review.problem.title)
  expect(page).not_to have_content(@other_review.problem.title)
end

Then("each due review shows its date and a link to practice") do
  [ @overdue_review, @today_review ].each do |review|
    within("tbody tr", text: review.problem.title) do
      expect(page).to have_content(review.next_review_date.strftime("%b %d, %Y"))
      expect(page).to have_link("Review Now", href: problem_path(review.problem))
    end
  end
end
