LINE_TIP = "Use a Set so each lookup is O(1).".freeze

Given("I have submitted a solution for {string}") do |title|
  @attempt = create_attempt(@user, slug: Problem.find_by!(title: title).slug)
end

Given("the AI reviewer has feedback about line {int}") do |line|
  tip = { category: "complexity", line_start: line, line_end: line, message: LINE_TIP }
  @ai_client = Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ tip ]))
  use_ai_client(@ai_client)
end

Given("the AI service is unavailable") do
  use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("connection refused")))
end

Given("the AI reviewer replies with something that is not a review") do
  use_ai_client(Ai::FakeClient.new(reply: "Sorry, I can't review code right now."))
end

When("I open my submission") { visit attempt_path(@attempt) }

When("I request an AI code review of my submission") do
  visit attempt_path(@attempt)
  click_button "Get AI code review"
end

When("I request an AI code review without the button") do
  @ai_client = Ai::FakeClient.new(reply: ai_review_reply)
  use_ai_client(@ai_client)
  page.driver.submit(:post, attempt_code_review_path(@attempt), {})
end

Then("I see the overall assessment and complexity") do
  expect(page).to have_content("Correct, but the nested scan is quadratic.")
  expect(page).to have_content("Time: O(n^2)")
end

Then("I see the feedback directly under line {int} of my code") do |line|
  code_line = page.find(".review-code > li:nth-child(#{line})")
  expect(code_line).to have_css(".review-suggestion", text: LINE_TIP)
  expect(page).to have_css(".review-suggestion", count: 1)
end

Then("I see the feedback under general suggestions") do
  expect(page).to have_css(".review-general", text: LINE_TIP)
  expect(page).not_to have_css(".review-suggestion")
end

Then("I am told the AI review is unavailable") do
  expect(page).to have_content("AI code review is unavailable right now")
end

Then("my submitted code is still shown") do
  expect(page.find(".saved-code").native.text.gsub(/\r\n?/, "\n")).to eq(@attempt.code)
end

Then("I am told AI code review is available to Premium members") do
  expect(page).to have_content("AI code review is available to Premium members.")
  expect(page).not_to have_button("Get AI code review")
end

Then("I am told AI code review is a Premium feature") do
  expect(page).to have_content("AI code review is a Premium feature.")
end

Then("the AI reviewer is not contacted") { expect(@ai_client.last_prompt).to be_nil }
