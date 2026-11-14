Given("the coach accepts my explanations") do
  use_ai_client(Ai::FakeClient.new(reply: { message: "That is correct. Continue.", advance: true }.to_json))
end

Given("the coach asks for clarification") do
  use_ai_client(Ai::FakeClient.new(reply: { message: "Please reconsider that explanation.", advance: false }.to_json))
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

Then("the step hint shines") { expect(page).to have_css(".coach-step.stage-shine") }

Then("no stage was just passed") { expect(page).not_to have_css(".coach-step.stage-shine") }

Then("I am notified that the editor is unlocked") do
  expect(page).to have_css("[data-testid='editor-unlocked']", text: "The editor is unlocked.")
  expect(page).to have_link("Go to editor", href: "#editor-title")
end

Then("I am not notified that the editor is unlocked") do
  expect(page).not_to have_css("[data-testid='editor-unlocked']")
end
