When("I visit my account") { visit account_path }

When("I click {string}") { |label| click_button label }

Then("I see my plan is {string}") do |role|
  expect(page).to have_css("h1", text: "My account")
  expect(page).to have_css("[data-testid='plan']", text: role)
end

Then("I can request an AI code review") { expect(page).to have_button("Get AI code review") }
