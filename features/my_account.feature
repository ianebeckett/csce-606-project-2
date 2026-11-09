Feature: My account
  As a member
  I want to see and change my plan
  So that I can choose between Free and Premium features

  Background:
    Given the six requested Easy problems are available

  Scenario: A Free member upgrades to Premium
    Given I am signed in as a "Free" member
    When I visit my account
    Then I see my plan is "Free"
    When I click "Upgrade to Premium"
    Then I see my plan is "Premium"
    And I see "You're now on Premium."

  Scenario: A Premium member downgrades to Free
    Given I am signed in as a "Premium" member
    When I visit my account
    And I click "Downgrade to Free"
    Then I see my plan is "Free"
    And I see "You're now on Free."

  Scenario: Upgrading unlocks Premium features
    Given I am signed in as a "Free" member
    And I have submitted a solution for "Contains Duplicate"
    When I visit my account
    And I click "Upgrade to Premium"
    And I open my submission
    Then I can request an AI code review

  Scenario: The account page requires signing in
    When I visit my account
    Then I am asked to sign in
