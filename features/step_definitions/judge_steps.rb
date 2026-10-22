Given("the six requested Easy problems are available") { seed_judge }

Given("I am signed in as a {string} member") do |role|
  @user = create_user(role: role)
  visit new_session_path
  fill_in "Email", with: @user.email
  fill_in "Password", with: "correct-horse-battery"
  click_button "Sign in"
  expect(page).to have_css("h1", text: "Problems")
end

When("I open the problem list without signing in") { visit problems_path }
Then("I am asked to sign in") { expect(page).to have_content("Please sign in to practice.") }
Then("no submission has been created") { expect(Attempt.count).to eq(0) }

When("I submit a correct Ruby solution for {string}") do |slug|
  @problem = Problem.find_by!(slug: slug)
  @submitted_code = RubySolutions::CORRECT.fetch(slug)
  visit problem_path(@problem)
  fill_in "Ruby source code", with: @submitted_code
  click_button "Submit Ruby solution"
  @attempt = Attempt.order(:id).last
end

Then("I see an {string} result with every predefined case passed") do |verdict|
  expect(page).to have_content(verdict)
  expect(page).to have_content("#{@problem.test_cases.count} / #{@problem.test_cases.count} test cases passed")
  expect(@attempt.reload.judge_result).to eq(verdict)
  expect(@attempt.total_cases).to be >= 5
end

Then("my submitted code is preserved in my personal history") do
  click_link "My submissions", match: :first
  click_link @problem.title
  expect(page.find(".saved-code").native.text.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
  expect(@attempt.reload.code.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
  expect(@attempt.user).to eq(@user)
end

When("I submit a Ruby solution with {string}") do |failure|
  @problem = Problem.find_by!(slug: "contains-duplicate")
  @submitted_code = {
    "wrong output" => "def contains_duplicate(nums); false; end",
    "invalid syntax" => "def contains_duplicate(nums)\n",
    "an exception" => "def contains_duplicate(nums); raise 'example failure'; end",
    "an endless loop" => "def contains_duplicate(nums); loop { sleep 0.1 }; end"
  }.fetch(failure)
  visit problem_path(@problem)
  fill_in "Ruby source code", with: @submitted_code
  click_button "Submit Ruby solution"
  @attempt = Attempt.order(:id).last
end

Then("I see the {string} verdict and a passed-case count") do |verdict|
  expect(page).to have_content(verdict)
  expect(page).to have_content("#{@attempt.passed_cases} / #{@attempt.total_cases} test cases passed")
  expect(@attempt.reload.judge_result).to eq(verdict)
end

Then("I can still open the problem and read my submitted code") do
  expect(@attempt.reload.code.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
  expect(page.find(".saved-code").native.text.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
  click_link "Try this problem again"
  expect(page).to have_content(@problem.title)
  expect(page).to have_field("Ruby source code")
end

Given("I am practicing just before midnight in Chicago") { travel_to(Time.utc(2026, 10, 21, 4, 59, 59)) }

Then("my two submissions belong to today's practice session") do
  @previous_session = @user.practice_sessions.sole
  expect(@previous_session.practice_date).to eq(Date.new(2026, 10, 20))
  expect(@previous_session.attempts.count).to eq(2)
  expect(@previous_session.attempts.pluck(:judge_result)).to eq([ "Compilation Error", "Compilation Error" ])
end

When("I submit again after midnight") do
  travel 1.second
  click_link "Try this problem again"
  click_button "Submit Ruby solution"
  @attempt = Attempt.order(:id).last
end

Then("only the new submission belongs to the new day's practice session") do
  expect(@user.practice_sessions.count).to eq(2)
  expect(@attempt.practice_session.practice_date).to eq(Date.new(2026, 10, 21))
  expect(@attempt.practice_session.attempts.pluck(:id)).to eq([ @attempt.id ])
  expect(@previous_session.reload.attempts.count).to eq(2)
  expect(@previous_session.status).to eq("in_progress")
  expect(page).to have_content("Compilation Error")
end

When("I try to submit a solution labelled {string}") do |language|
  problem = Problem.first
  page.driver.submit(:post, problem_attempts_path(problem), { attempt: { code: "puts 1", language: language } })
end

Then("the page explains that only Ruby is supported") { expect(page).to have_content("only Ruby is supported") }

When("I submit an empty Ruby solution") do
  page.driver.submit(:post, problem_attempts_path(Problem.first), { attempt: { code: "", language: "ruby" } })
end
Then("the page explains that code is required") { expect(page).to have_content("Code can't be blank") }

Given("a problem has fewer than five predefined cases") do
  @problem = Problem.first
  @problem.test_cases.limit(@problem.test_cases.count - 4).destroy_all
end

When("I try to submit to that problem") do
  page.driver.submit(:post, problem_attempts_path(@problem), { attempt: { code: "puts 1", language: "ruby" } })
end
Then("the page explains that the problem is not ready for judging") { expect(page).to have_content("not ready for judging") }

Given("a different member has submitted a solution") do
  other = create_user(email: "other@example.com")
  @other_attempt = other.practice_sessions.create!(problem: Problem.first, started_at: Time.current).attempts.create!(
    code: "private_submission_code", language: "ruby")
end
When("I request the different member's submission") { visit attempt_path(@other_attempt) }
Then("I cannot see that submission or its code") do
  expect(page.status_code).to eq(404)
  expect(page).not_to have_content("private_submission_code")
end

When("I register with a valid email and password") do
  visit new_registration_path
  fill_in "Email", with: "new@example.com"
  fill_in "Password (at least 12 characters)", with: "correct-horse-battery"
  fill_in "Confirm password", with: "correct-horse-battery"
  click_button "Create account"
end
Then("I see all six requested topics") do
  expect(page).to have_css("h1", text: "Problems")
  Topic.pluck(:name).each { |name| expect(page).to have_content(name) }
end
Then("I can sign out and sign back in") do
  click_button "Sign out"
  fill_in "Email", with: "new@example.com"
  fill_in "Password", with: "correct-horse-battery"
  click_button "Sign in"
  expect(page).to have_css("h1", text: "Problems")
end

Given("a learner account exists") { create_user }
When("I sign in with an incorrect password") do
  visit new_session_path
  fill_in "Email", with: "learner@example.com"
  fill_in "Password", with: "incorrect-password"
  click_button "Sign in"
end
Then("the page explains that the credentials are invalid") { expect(page).to have_content("Invalid email or password.") }
Then("I am still asked to sign in when opening the problems") do
  visit problems_path
  expect(page).to have_content("Please sign in to practice.")
end
When("I open my submissions") { visit attempts_path }
Then("I see that I have not submitted any code yet") { expect(page).to have_content("No submissions yet.") }
