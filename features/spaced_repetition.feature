
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
    And I select the upcoming reviews "View All" link
    Then I see all three upcoming reviews in date order

  Scenario Outline: Adjust an existing review interval after completed practice
    Given I am signed in as a "Free" member
    And I have a completed coding attempt with a 4-day review interval
    When I rate that practice <rating>
    Then my next review is scheduled in <days> days
    And my completed practice records that rating
    Examples:
      | rating | days |
      | 2      | 2    |
      | 3      | 4    |
      | 4      | 8    |
      | 5      | 12   |

  Scenario Outline: Reject a rating request without changing saved progress
    Given I am signed in as a "Free" member
    And I have a completed coding attempt with a 4-day review interval
    When I try to rate that practice with "<request>"
    Then I see the rating rejection "<message>"
    And my practice and review schedule are unchanged
    Examples:
      | request                  | message                              |
      | an invalid rating        | Select a rating from 1 to 5.          |
      | an older attempt         | Only the latest attempt can be rated. |
      | an unfinished attempt    | Complete a coding attempt first.      |
      | an already rated attempt | This attempt has already been rated.  |

  Scenario: View only my due reviews in due-date order
    Given I am signed in as a "Free" member
    And I have overdue, due-today, future, and another member's reviews
    When I open the due reviews page
    Then I see only my overdue and due-today reviews in date order
    And each due review shows its date and a link to practice

  Scenario: A learner with no due reviews sees an empty list
    Given I am signed in as a "Free" member
    When I open the due reviews page
    Then I see "No problems are due for review. Great job!"
