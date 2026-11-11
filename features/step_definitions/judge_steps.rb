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
Given("I have completed the prerequisites for {string}") do |slug|
  complete_prerequisites(@user, Problem.find_by!(slug: slug).topic)
end
Then("I am asked to sign in") { expect(page).to have_content("Please sign in to practice.") }
Then("no submission has been created") { expect(Attempt.count).to eq(0) }

Given("the judge queue contains {int} Pending submissions") do |count|
  expect(Judge::Queue::MAX_PENDING).to eq(10)
  problem = Problem.find_by!(slug: "contains-duplicate")
  other = create_user(email: "queue-owner@example.com")
  session = other.practice_sessions.for_today(problem)
  count.times do
    session.attempts.create!(code: "earlier submission", total_cases: problem.test_cases.count)
  end
  @pending_count = Attempt.count
end

Then("I am told when to retry without losing my code") do
  expect(page.status_code).to eq(503)
  expect(page.response_headers.fetch("Retry-After")).to eq("65")
  expect(page).to have_content("The judge is at capacity (10 pending submissions)")
  expect(page).to have_content("try again in about 65 seconds")
  expect(page).to have_content("not queued")
  expect(page.find_field("Ruby source code").value.gsub(/\r\n?/, "\n")).to eq(@submitted_code)
  expect(Attempt.count).to eq(@pending_count)
  expect(enqueued_jobs).to be_empty
end

Then("I see a Pending result with 9 submissions ahead and an estimated wait of 545 seconds") do
  expect(@attempt.reload.judge_result).to eq(Attempt::PENDING)
  expect(Attempt.where(judge_result: Attempt::PENDING).count).to eq(10)
  expect(page).to have_content(Attempt::PENDING)
  expect(page).to have_content("9 submissions ahead")
  expect(page).to have_content("about 545 seconds")
  expect(page).to have_content("estimate")
  expect(page).to have_link("Refresh result", href: attempt_path(@attempt))
end

When("I submit a correct Ruby solution for {string}") do |slug|
  @problem = Problem.find_by!(slug: slug)
  @submitted_code = RubySolutions::CORRECT.fetch(slug)
  finish_coaching(@user, @problem)
  visit problem_path(@problem)
  fill_in "Ruby source code", with: @submitted_code
  click_button "Submit Ruby solution"
  @attempt = Attempt.order(:id).last
end

When("I submit a correct {string} solution for {string}") do |language, slug|
  @problem = Problem.find_by!(slug: slug)
  @submitted_code = LanguageSolutions::CORRECT.fetch(language).fetch(slug)
  visit problem_path(@problem, language: language)
  fill_in "#{Attempt.language_name(language)} source code", with: @submitted_code
  click_button "Submit #{Attempt.language_name(language)} solution"
  @attempt = Attempt.order(:id).last
end

Then("the submission shows {string}") { |version| expect(page).to have_content(version) }

When("I submit invalid {string} syntax") do |language|
  @problem = Problem.find_by!(slug: "contains-duplicate")
  @submitted_code = LanguageSolutions::INVALID.fetch(language)
  visit problem_path(@problem, language: language)
  fill_in "#{Attempt.language_name(language)} source code", with: @submitted_code
  click_button "Submit #{Attempt.language_name(language)} solution"
  @attempt = Attempt.order(:id).last
end

Then("the page says that my code could not be compiled") do
  expect(page).to have_content("Your code could not be compiled.")
end

Then("compiler output is not displayed") do
  expect(page).not_to have_content("SyntaxError")
  expect(page).not_to have_content("syntax error")
  expect(page).not_to have_content("expected declaration")
end

Then("I first see a {string} result") do |verdict|
  expect(page).to have_content(verdict)
  expect(@attempt.reload.judge_result).to eq(verdict)
  expect(page).to have_link("Refresh result", href: attempt_path(@attempt))
end

When("judging finishes") do
  perform_enqueued_jobs
  click_link "Refresh result"
end

Then("I see an {string} result with every predefined case passed") do |verdict|
  expect(page).to have_content(verdict)
  expect(page).to have_content("#{@problem.test_cases.count} / #{@problem.test_cases.count} test cases passed")
  expect(@attempt.reload.judge_result).to eq(verdict)
  expect(@attempt.total_cases).to be >= 5
  expect(page).not_to have_link("Refresh result")
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
    "an abrupt exit" => "def contains_duplicate(nums); exit!(125); end",
    "an endless loop" => "def contains_duplicate(nums); loop { sleep 0.1 }; end"
  }.fetch(failure)
  finish_coaching(@user, @problem)
  visit problem_path(@problem)
  fill_in "Ruby source code", with: @submitted_code
  click_button "Submit Ruby solution"
  @attempt = Attempt.order(:id).last
end

Then("I see the {string} verdict and a passed-case count") do |verdict|
  @attempt.reload
  expect(page).to have_content(verdict)
  expect(page).to have_content("#{@attempt.passed_cases} / #{@attempt.total_cases} test cases passed")
  expect(@attempt.judge_result).to eq(verdict)
  expect(page).not_to have_link("Refresh result")
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
  perform_enqueued_jobs
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
  perform_enqueued_jobs
  click_link "Refresh result"
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

Then("the page explains that the language is not supported") { expect(page).to have_content("is not supported") }

Given("the remote judge cannot be reached") do
  @previous_judge_url = ENV["JUDGE_URL"]
  @previous_judge_token = ENV["JUDGE_TOKEN"]
  @remote_judge_configured = true
  ENV["JUDGE_URL"] = "https://127.0.0.1:1/execute"
  ENV["JUDGE_TOKEN"] = "acceptance-secret"
end

Given("Heroku can create an isolated one-off judge dyno") do
  problem = Problem.find_by!(slug: "contains-duplicate")
  outputs = problem.test_cases.order(:position).map(&:expected_output)
  response = Struct.new(:code, :body)
  api_class = Class.new(Judge::HerokuDynoRunner::Api) do
    define_method(:request) do |_uri, _request|
      response.new("201", JSON.generate(attach_url: "rendezvous://rendezvous.runtime.heroku.com:5000/secret"))
    end
  end
  chunks = [ JSON.generate(status: "ok", outputs: outputs, runtime: "Go 1.27.3") ]
  socket = Object.new
  socket.define_singleton_method(:write) { |value| value.bytesize }
  socket.define_singleton_method(:gets) { "connected\n" }
  socket.define_singleton_method(:readpartial) { |_size| chunks.empty? ? raise(EOFError) : chunks.shift }
  socket.define_singleton_method(:close) { }
  runner = Judge::HerokuDynoRunner.new(
    app: "codecoach-judge", token: "platform-secret", api: api_class.new,
    rendezvous: Judge::HerokuDynoRunner::Rendezvous.new(socket_factory: ->(_uri) { socket })
  )
  @original_judge_runner_build = Judge::Runner.method(:build)
  Judge::Runner.define_singleton_method(:build) { runner }
end

When("I submit an empty Ruby solution") do
  @problem = Problem.first
  @submitted_code = ""
  visit problem_path(@problem)
  expect(page.find_field("Ruby source code")[:required]).to be_nil
  fill_in "Ruby source code", with: @submitted_code
  expect { click_button "Submit Ruby solution" }.to change(Attempt, :count).by(1)
  @attempt = @user.attempts.order(:id).last
end
Then("the page explains that code is required") { expect(page).to have_content("Code can't be blank") }

Then("I can retry with the problem's starter code") do
  click_link "Try this problem again"
  expect(page).to have_field("Ruby source code", with: @problem.starter_code)
  expect(@attempt.reload.code).to eq("")
end

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
