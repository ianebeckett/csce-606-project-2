Feature: US1 — Roadmap & Problem Discovery
  As a coding interview candidate
  I want to explore a prerequisite-aware roadmap and discover topic problems
  So that I know what to learn and practice next

  Background:
    Given the six requested Easy problems are available

  Scenario: The roadmap requires login
    When I open the problem list without signing in
    Then I am asked to sign in
    And no submission has been created

  Scenario Outline: Explore an unlocked topic without JavaScript
    Given I am signed in as a "<role>" member
    When I select the "Arrays & Hashing" topic
    Then I see "Contains Duplicate" with difficulty "Easy" and status "Not solved"
    And I do not see problems from other topics
    And the roadmap shows "Arrays & Hashing" as "In Progress"
    And the roadmap shows "Two Pointers" as "Locked"
    Examples:
      | role    |
      | Free    |
      | Premium |

  @docker
  Scenario: A correct judged solution masters a topic and unlocks its dependent topic
    Given I am signed in as a "Free" member
    When I submit a correct Ruby solution for "contains-duplicate"
    And I open the roadmap
    Then the roadmap shows "Arrays & Hashing" as "Mastered"
    And the roadmap shows "Two Pointers" as "In Progress"
    And I see "Contains Duplicate" with difficulty "Easy" and status "Accepted"
    When I select the "Two Pointers" topic
    Then I can open "Valid Palindrome" for practice

  Scenario Outline: Locked topics cannot be accessed directly
    Given I am signed in as a "Free" member
    When I try to access the locked topic through "<entry>"
    Then I see that I must master "Arrays & Hashing" first
    And no submission has been created
    Examples:
      | entry      |
      | topic      |
      | problem    |
      | submission |

  Scenario: Another member's progress does not unlock my topics
    Given I am signed in as a "Free" member
    And another member has mastered "Arrays & Hashing"
    When I open the roadmap
    Then the roadmap shows "Arrays & Hashing" as "In Progress"
    And the roadmap shows "Two Pointers" as "Locked"
    And I see "Contains Duplicate" with difficulty "Easy" and status "Not solved"

  Scenario: Empty topics explain that problems are not available yet
    Given the topic "Dynamic Programming" has no problems
    And I am signed in as a "Free" member
    When I select the "Dynamic Programming" topic
    Then I see "No problems are available in this topic yet."
    And the roadmap shows "Dynamic Programming" as "In Progress"
