
Feature: US2 — Spaced Repetition
  As a learner
  I want completed practice problems scheduled for review
  So that I can retain concepts over time

  Background:
    Given the six requested Easy problems are available

  Scenario Outline: Rated practice produces a due review on the dashboard
    Given I am signed in as a "<role>" member
    And I completed and rated "Contains Duplicate" two days ago
    When I open the roadmap
    Then I see "Due Reviews"
    And I see "Contains Duplicate" in my due reviews
    And I see the saved review date
    And I see "Unlocked problems"

    Examples:
      | role    |
      | Free    |
      | Premium |

  Scenario: A learner with no review history sees an empty state
    Given I am signed in as a "Free" member
    When I open the roadmap
    Then I see "No problems are due for review."
    And I see "Unlocked problems"

  Scenario: The dashboard previews the two soonest upcoming reviews
    Given I am signed in as a "Free" member
    And I have three upcoming reviews scheduled
    When I open the roadmap
    Then I see the two soonest upcoming reviews on the dashboard
    And I see the dates for those upcoming reviews
    And I can open the full upcoming reviews list

  Scenario: A learner can view all upcoming reviews
    Given I am signed in as a "Free" member
    And I have three upcoming reviews scheduled
    When I open the roadmap
    And I select the upcoming reviews "View all" link
    Then I see all three upcoming reviews in date order
