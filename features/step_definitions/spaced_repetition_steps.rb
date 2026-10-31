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
