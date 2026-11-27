# Create a practice session with coaching dialogue.
Given("I have a coaching conversation for {string}") do |title|
  @problem = Problem.find_by!(title: title)

  @practice_session = @user.practice_sessions.create!(
    problem: @problem,
    started_at: Time.current
  )

  @practice_session.conversation_messages.create!(
    role: "user",
    phase: "coaching",
    content: "I would use a hash set to track duplicates."
  )

  @practice_session.conversation_messages.create!(
    role: "assistant",
    phase: "coaching",
    content: "How would that help identify duplicates?"
  )
end

# Configure a predictable AI response for the acceptance test.
Given("AI feedback is available") do
  feedback = {
    summary: "Good understanding of the problem.",
    conceptual_accuracy: {
      assessment: "The approach was correct.",
      strengths: [ "Recognized the need to track duplicates." ],
      weaknesses: []
    },
    explanation_quality: {
      assessment: "The explanation was clear.",
      strengths: [ "Explained the approach clearly." ],
      weaknesses: []
    },
    actionable_tips: [ "Explain time complexity more clearly." ]
  }

  use_ai_client(Ai::FakeClient.new(reply: feedback.to_json))
end

# Complete the practice session through the actual rating form.
When("I complete practice with a rating of {int}") do |rating|
  @attempt = @practice_session.attempts.create!(
    code: @problem.starter_code,
    language: "ruby",
    judge_result: Attempt::ACCEPTED,
    passed_cases: @problem.test_cases.count,
    total_cases: @problem.test_cases.count
  )

  visit attempt_path(@attempt)
  choose "review_rating_#{rating}"
  click_button "Complete Practice"
end

Then("I see my post-session feedback") do
  expect(page).to have_content("Your Coaching Feedback")
  expect(page).to have_content("Good understanding of the problem.")
end

Then("I see feedback about conceptual accuracy") do
  expect(page).to have_content("Conceptual Accuracy")
  expect(page).to have_content("The approach was correct.")
end

Then("I see feedback about explanation quality") do
  expect(page).to have_content("Explanation Quality")
  expect(page).to have_content("The explanation was clear.")
end

Then("I see actionable improvement tips") do
  expect(page).to have_content("Actionable Tips")
  expect(page).to have_content("Explain time complexity more clearly.")
end

# Simulate an unavailable AI service.
Given("AI feedback is unavailable") do
  use_ai_client(
    Ai::FakeClient.new(error: Ai::Error.new("AI unavailable"))
  )
end

Then("my practice session is completed") do
  expect(@practice_session.reload.status).to eq("completed")
end

Then("my next review is scheduled") do
  expect(@practice_session.reload.review_scheduled_at).to be_present
end

Then("no post-session feedback is displayed") do
  expect(page).not_to have_content("Your Coaching Feedback")
end

When("I call the unconfigured AI client") do
  @unconfigured_client = Ai::UnconfiguredClient.new
end

Then("it raises the missing AI provider error") do
  expect {
    @unconfigured_client.complete(
      system: "Test system",
      prompt: "Test prompt"
    )
  }.to raise_error(Ai::NotConfigured, "OPENAI_API_KEY is not set")
end
