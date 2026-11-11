Feature: Turn-based interview
  As a Premium member
  I want to practice a problem as a turn-based interview
  So that I learn to clarify, plan and adapt before coding

  Background:
    Given the six requested Easy problems are available

  Scenario: Clarifying the problem shows what I have learned
    Given I am signed in as a "Premium" member
    And the interviewer accepts my answers
    When I start the interview for "Contains Duplicate"
    Then I see only the vague problem
    When I ask the interviewer "How big can the list be?"
    Then I see what I've learned about the problem

  Scenario: Adapting to the twist unlocks the editor
    Given I am signed in as a "Premium" member
    And the interviewer accepts my answers
    When I start the interview for "Contains Duplicate"
    And I ask the interviewer "How big can the list be?"
    And I tell the interviewer "Compare every pair with a nested loop."
    Then the interviewer changes the requirement
    When I tell the interviewer "I would switch to a hash set and stop at the first repeat."
    Then the code editor is unlocked

  Scenario: An interviewer who is not satisfied keeps the editor locked
    Given I am signed in as a "Premium" member
    And the interviewer wants more detail
    When I start the interview for "Contains Duplicate"
    And I ask the interviewer "How big can the list be?"
    Then the code editor is locked
    And I see both turns in the interview history

  Scenario: An outage keeps my message and unlocks the editor
    Given I am signed in as a "Premium" member
    And the AI service is unavailable
    When I start the interview for "Contains Duplicate"
    And I ask the interviewer "How big can the list be?"
    Then I see "The interviewer is unavailable right now. Your message is saved, and the editor is unlocked."
    And my message "How big can the list be?" is in the interview history
    And the code editor is unlocked

  Scenario: A Free member cannot use the interviewer
    Given I am signed in as a "Free" member
    When I start the interview for "Contains Duplicate"
    Then I see "The interviewer is a Premium feature."

  @real_ai
  Scenario: The real AI answers a clarifying question
    Given I am signed in as a "Premium" member
    And the interviewer is the real AI
    When I start the interview for "Contains Duplicate"
    And I ask the interviewer "How big can the list be?"
    Then the interviewer replied
    And the code editor is locked
