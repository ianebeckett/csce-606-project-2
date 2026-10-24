Feature: US7 — Online Judge & Error Recovery
  As a candidate
  I want to execute my Ruby code against predefined cases and see clear outcomes
  So that I can verify and debug my solution

  Background:
    Given the six requested Easy problems are available

  Scenario: Ruby practice requires signing in
    When I open the problem list without signing in
    Then I am asked to sign in
    And no submission has been created

  Scenario Outline: Solve a real problem using Ruby without JavaScript
    Given I am signed in as a "<role>" member
    And I have completed the prerequisites for "<slug>"
    When I submit a correct Ruby solution for "<slug>"
    Then I see an "Accepted" result with every predefined case passed
    And my submitted code is preserved in my personal history
    Examples:
      | role    | slug                       |
      | Free    | contains-duplicate         |
      | Premium | valid-palindrome           |
      | Free    | valid-parentheses          |
      | Premium | binary-search              |
      | Free    | maximum-average-subarray-i |
      | Premium | reverse-linked-list        |

  Scenario Outline: Recover from a Ruby submission failure
    Given I am signed in as a "Free" member
    When I submit a Ruby solution with "<failure>"
    Then I see the "<verdict>" verdict and a passed-case count
    And I can still open the problem and read my submitted code
    Examples:
      | failure        | verdict           |
      | wrong output   | Wrong Answer      |
      | invalid syntax | Compilation Error |
      | an exception   | Runtime Error     |
      | an abrupt exit | Runtime Error     |
      | an endless loop| Timeout           |

  Scenario: Keep same-day retries together and start a new session after midnight
    Given I am signed in as a "Free" member
    And I am practicing just before midnight in Chicago
    When I submit a Ruby solution with "invalid syntax"
    And I submit a Ruby solution with "invalid syntax"
    Then my two submissions belong to today's practice session
    When I submit again after midnight
    Then only the new submission belongs to the new day's practice session

  Scenario: Reject a non-Ruby submission at the server
    Given I am signed in as a "Free" member
    When I try to submit a solution labelled "python"
    Then the page explains that only Ruby is supported
    And no submission has been created

  Scenario: Keep an empty Ruby submission in my history
    Given I am signed in as a "Free" member
    When I submit an empty Ruby solution
    Then I see the "Runtime Error" verdict and a passed-case count
    And the page explains that code is required
    And my submitted code is preserved in my personal history
    And I can retry with the problem's starter code

  Scenario: Do not judge a problem with too few cases
    Given I am signed in as a "Free" member
    And a problem has fewer than five predefined cases
    When I try to submit to that problem
    Then the page explains that the problem is not ready for judging
    And no submission has been created

  @allow-rescue
  Scenario: Another member cannot read my submission
    Given I am signed in as a "Free" member
    And a different member has submitted a solution
    When I request the different member's submission
    Then I cannot see that submission or its code

  Scenario: New accounts can start practicing
    When I register with a valid email and password
    Then I see all six requested topics
    When I open my submissions
    Then I see that I have not submitted any code yet
    And I can sign out and sign back in

  Scenario: Invalid credentials do not authenticate
    Given a learner account exists
    When I sign in with an incorrect password
    Then the page explains that the credentials are invalid
    And I am still asked to sign in when opening the problems
