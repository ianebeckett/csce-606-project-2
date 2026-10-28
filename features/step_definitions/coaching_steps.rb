Given("the coach is connected to the real AI") do
  use_ai_client(Ai::OpenAiClient.new(api_key: ENV.fetch("OPENAI_API_KEY")))
end

# A real request with a key OpenAI rejects, so the failure is genuine.
Given("the AI service rejects the coach's requests") do
  use_ai_client(Ai::OpenAiClient.new(api_key: "sk-invalid-key-for-testing"))
end

When("I open the problem {string}") do |title|
  @problem = Problem.find_by!(title: title)
  visit problem_path(@problem)
end

When("I tell the coach {string}") do |text|
  (@my_messages ||= []) << text
  fill_in "Your message", with: text
  click_button "Send"
end

Then("the code editor is locked") { expect(page).not_to have_field("Ruby source code") }

Then("the code editor is unlocked") { expect(page).to have_field("Ruby source code") }

Then("I see my conversation with the coach") do
  coach_replies = @user.practice_sessions.for_today(@problem).conversation_messages.where(role: "assistant")
  expect(coach_replies.count).to eq(@my_messages.size)
  (@my_messages + coach_replies.pluck(:content)).each { |text| expect(page).to have_content(text) }
end

Then("I see my message in the conversation") do
  @my_messages.each { |text| expect(page).to have_content(text) }
end

Then("I am told the coach is unavailable") { expect(page).to have_content("unavailable") }
