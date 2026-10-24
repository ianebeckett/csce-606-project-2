Feature: US6 — Learning History
  As a learner
  I want to review my practice history and performance trends
  So that I can recognize progress and weak topics

  Background:
    Given the six requested Easy problems are available

  Scenario Outline: Review my attempts and performance
    Given I am signed in as a "<role>" member
    And I have a solved attempt with a review and AI dialogue
    When I visit my learning history
    Then I see my solved and review counts
    And I see my attempt and topic progress
    When I open the attempt details
    Then I see my submitted code, judge outcome, and AI dialogue
    Examples:
      | role    |
      | Free    |
      | Premium |

  Scenario: An account with no history sees an empty state
    Given I am signed in as a "Free" member
    When I visit my learning history
    Then I see zero counts and an empty history message

  @allow-rescue
  Scenario: I cannot view another member's history
    Given I am signed in as a "Free" member
    And another member has a private attempt
    When I open the other member's history
    Then the history page is not found and the code stays private

  Scenario: History requires signing in
    When I visit my learning history
    Then I am asked to sign in
