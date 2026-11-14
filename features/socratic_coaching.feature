Feature: US4 — Socratic Conceptual Auditing
  As a candidate
  I want to explain my algorithm before coding and answer follow-up questions
  So that I can discover gaps in my reasoning

  Background:
    Given the six requested Easy problems are available

  Scenario: Explaining the problem and a correct approach unlocks the editor
    Given I am signed in as a "Premium" member
    And the coach accepts my explanations
    When I open the problem "Contains Duplicate"
    Then the code editor is locked
    When I tell the coach "Given an array of integers, return true if any value appears at least twice, and false if every value is distinct."
    And I tell the coach "Walk through the array once, keeping a hash set of the numbers seen so far. If the current number is already in the set, return true. If the loop ends, return false."
    Then the code editor is unlocked
    And I see my conversation with the coach

  Scenario: A wrong approach keeps the editor locked
    Given I am signed in as a "Premium" member
    And the coach asks for clarification
    When I open the problem "Contains Duplicate"
    And I tell the coach "Given an array of integers, return true if any value appears at least twice, and false if every value is distinct."
    And I tell the coach "Sort the array in descending order and return true if the first element is positive."
    Then I see my conversation with the coach
    And the code editor is locked

  Scenario: When the coach is unavailable I keep my message and can code
    Given I am signed in as a "Premium" member
    And the AI service is unavailable
    When I open the problem "Contains Duplicate"
    And I tell the coach "Return true if any number appears twice in the array."
    Then I am told the coach is unavailable
    And I see my message in the conversation
    And the code editor is unlocked

  Scenario: Passing each stage is celebrated
    Given I am signed in as a "Premium" member
    And the coach accepts my explanations
    When I open the problem "Contains Duplicate"
    Then stage "Restate the problem" is the current stage
    When I tell the coach "Given an array of integers, return true if any value appears at least twice, and false if every value is distinct."
    Then I see "Stage 1 passed: you understand the problem."
    And stage "Restate the problem" is passed
    And stage "Explain your approach" is the current stage
    When I tell the coach "Walk through the array once, keeping a hash set of the numbers seen so far. If the current number is already in the set, return true. If the loop ends, return false."
    Then I see "Stage 2 passed: your approach works."

  Scenario: A reply that does not pass a stage shows no stage effect
    Given I am signed in as a "Premium" member
    And the coach asks for clarification
    When I open the problem "Contains Duplicate"
    And I tell the coach "It is about numbers."
    Then I see no stage-passed message
    And stage "Restate the problem" is the current stage
