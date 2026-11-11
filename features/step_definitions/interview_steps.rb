Given("the interviewer accepts my answers") do
  use_ai_client(Ai::FakeClient.new(reply: { message: "Good, go on.", advance: true }.to_json))
end

Given("the interviewer wants more detail") do
  use_ai_client(Ai::FakeClient.new(reply: { message: "Can you say more?", advance: false }.to_json))
end

Given("the interviewer is the real AI") do
  client = Ai.client_from_env
  skip_this_scenario("OPENAI_API_KEY is not set") unless client
  use_ai_client(client)
end

When("I start the interview for {string}") do |title|
  @problem = Problem.find_by!(title: title)
  visit problem_interview_path(@problem)
end

When(/^I (?:ask|tell) the interviewer "([^"]*)"$/) do |text|
  fill_in "Your message", with: text
  click_button "Send"
end

Then("I see only the vague problem") do
  expect(page).to have_content(@problem.interview_prompt)
  expect(page).not_to have_content(@problem.description)
end

Then("I see what I've learned about the problem") do
  expect(page).to have_content("What you've learned")
  expect(page).to have_content(@problem.interview_details.first["fact"])
  expect(page).not_to have_content(@problem.description)
end

Then("the interviewer changes the requirement") { expect(page).to have_content(@problem.interview_twist) }

Then("I see both turns in the interview history") do
  expect(page).to have_css(".conversation-message.user", text: "How big can the list be?")
  expect(page).to have_css(".conversation-message.assistant", text: "Can you say more?")
end

Then("my message {string} is in the interview history") do |text|
  expect(page).to have_css(".conversation-message.user", text: text)
end

Then("the interviewer replied") do
  reply = @user.practice_sessions.for_today(@problem).conversation_messages.interview.where(role: "assistant")
  expect(reply.count).to eq(1)
  expect(page.text.squish).to include(reply.first.content.squish)
end
