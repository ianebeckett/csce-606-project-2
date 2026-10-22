When("I open the roadmap") { visit problems_path }

When("I select the {string} topic") do |name|
  within(".topic-panel") { click_link name, exact: true }
end

Then("I see {string} with difficulty {string} and status {string}") do |title, difficulty, status|
  row = find(".problem-row", text: title)
  expect(row).to have_content(difficulty)
  expect(row).to have_css(".problem-status", text: status)
end

Then("I do not see problems from other topics") do
  expect(page).to have_css(".problem-row", count: 1)
  expect(page).not_to have_content("Valid Palindrome")
end

Then("the roadmap shows {string} as {string}") do |name, status|
  within(find(".topic-link", exact_text: name).ancestor(".roadmap-topic")) do
    expect(page).to have_css(".topic-status", text: status)
    expect(page).not_to have_link(name) if status == "Locked"
  end
end

Then("I can open {string} for practice") do |title|
  click_link title, exact: true
  expect(page).to have_css("h1", text: title)
  expect(page).to have_field("Ruby source code")
end

When("I try to access the locked topic through {string}") do |entry|
  topic = Topic.find_by!(name: "Two Pointers")
  case entry
  when "topic" then visit problems_path(topic: topic.id)
  when "problem" then visit problem_path(topic.problems.first)
  when "submission"
    page.driver.submit(:post, problem_attempts_path(topic.problems.first), { attempt: { code: "puts 1", language: "ruby" } })
  end
end

Then("I see that I must master {string} first") do |name|
  expect(page.status_code).to eq(403)
  expect(page).to have_content("Topic locked")
  expect(page).to have_content(name)
  expect(page).not_to have_field("Ruby source code")
end

Given("another member has mastered {string}") do |name|
  other = create_user(email: "other@example.com")
  Topic.find_by!(name: name).problems.each do |problem|
    other.practice_sessions.for_today(problem).attempts.create!(code: problem.starter_code, language: "ruby", judge_result: Attempt::ACCEPTED)
  end
end

Given("the topic {string} has no problems") do |name|
  Topic.create!(name: name, position: 6)
end

Then("I see {string}") { |text| expect(page).to have_content(text) }
