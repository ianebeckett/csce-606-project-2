Feature: US3 — AI Code Review
  As a candidate
  I want AI feedback on my submitted code
  So that I can improve correctness, efficiency, and code quality

  Background:
    Given the six requested Easy problems are available

  Scenario: A Premium member gets feedback tied to their code
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And the AI reviewer has feedback about line 2
    When I request an AI code review of my submission
    Then I see the overall assessment and complexity
    And I see the feedback directly under line 2 of my code

  Scenario: Feedback about a line that does not exist is shown as general advice
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And the AI reviewer has feedback about line 99
    When I request an AI code review of my submission
    Then I see the feedback under general suggestions

  Scenario: The AI service fails
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And the AI service is unavailable
    When I request an AI code review of my submission
    Then I am told the AI review is unavailable
    And my submitted code is still shown

  Scenario: The AI reply cannot be used
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And the AI reviewer replies with something that is not a review
    When I request an AI code review of my submission
    Then I am told the AI review is unavailable
    And my submitted code is still shown

  Scenario: A Free member cannot get an AI code review
    Given I am signed in as a "Free" member
    And I have submitted a solution for "Contains Duplicate"
    When I open my submission
    Then I am told AI code review is available to Premium members
    When I request an AI code review without the button
    Then I am told AI code review is a Premium feature
    And the AI reviewer is not contacted

  Scenario: A review through the OpenAI provider is tied to the code
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And OpenAI replies with feedback about line 2
    When I request an AI code review of my submission
    Then I see the feedback directly under line 2 of my code

  Scenario: OpenAI is having an outage
    Given I am signed in as a "Premium" member
    And I have submitted a solution for "Contains Duplicate"
    And OpenAI is having an outage
    When I request an AI code review of my submission
    Then I am told the AI review is unavailable
    And my submitted code is still shown
