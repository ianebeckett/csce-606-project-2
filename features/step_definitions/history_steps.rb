Given("I have a solved attempt with a review and AI dialogue") do
  @history_problem = Problem.first
  @history_code = @history_problem.starter_code
  @history_attempt = @user.practice_sessions.for_today(@history_problem).attempts.create!(
    code: @history_code,
    judge_result: Attempt::ACCEPTED,
    passed_cases: @history_problem.test_cases.count,
    total_cases: @history_problem.test_cases.count
  )
  @user.review_schedules.create!(problem: @history_problem, scheduled_for: Date.current)
  session = @history_attempt.practice_session
  session.conversation_messages.create!(role: "user", content: "Why does this pass?")
  session.conversation_messages.create!(role: "assistant", content: "It handles the required cases.")
end

When("I visit my learning history") { visit history_index_path }

Then("I see my solved and review counts") do
  expect(page).to have_content("Problems solved: 1")
  expect(page).to have_content("Reviews scheduled: 1")
end

Then("I see my attempt and topic progress") do
  expect(page).to have_link(@history_problem.title, href: history_path(@history_attempt))
  expect(page).to have_content(@history_problem.topic.name)
  expect(page).to have_content("1 / 1 problems solved")
  expect(page).to have_content(Attempt::ACCEPTED)
end

When("I open the attempt details") do
  click_link @history_problem.title
end

Then("I see my submitted code, judge outcome, and AI dialogue") do
  displayed_code = page.find("pre code").native.text.gsub(/\r\n?/, "\n")
  expect(displayed_code).to eq(@history_code)
  expect(page).to have_content(Attempt::ACCEPTED)
  expect(page).to have_content("Why does this pass?")
  expect(page).to have_content("It handles the required cases.")
end

Then("I see zero counts and an empty history message") do
  expect(page).to have_content("Problems solved: 0")
  expect(page).to have_content("Reviews scheduled: 0")
  expect(page).to have_content("No practice history yet.")
end

Given("another member has a private attempt") do
  other_user = create_user(email: "other@example.com")
  @private_attempt = other_user.practice_sessions.for_today(Problem.first).attempts.create!(
    code: "private_history_code",
    judge_result: Attempt::WRONG_ANSWER
  )
end

When("I open the other member's history") do
  visit history_path(@private_attempt)
end

Then("the history page is not found and the code stays private") do
  expect(page.status_code).to eq(404)
  expect(page).not_to have_content("private_history_code")
end
