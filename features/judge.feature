Feature: US7 — Online Judge & Error Recovery
  As a candidate
  I want to execute my code against predefined cases and see clear outcomes
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
    Then I first see a "Pending" result
    When judging finishes
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

  Scenario Outline: Choose another supported language without JavaScript
    Given I am signed in as a "Free" member
    When I submit a correct "<language>" solution for "contains-duplicate"
    Then I first see a "Pending" result
    When judging finishes
    Then I see an "Accepted" result with every predefined case passed
    And the submission shows "<version>"
    Examples:
      | language | version            |
      | python   | Python 3.15.2      |
      | go       | Go 1.27.3          |
      | cpp      | C++23 (GCC 16.2.0) |

  Scenario Outline: Show a concise compilation error
    Given I am signed in as a "Free" member
    When I submit invalid "<language>" syntax
    Then I first see a "Pending" result
    When judging finishes
    Then I see the "Compilation Error" verdict and a passed-case count
    And the page says that my code could not be compiled
    And compiler output is not displayed
    Examples:
      | language |
      | ruby     |
      | python   |
      | go       |
      | cpp      |

  Scenario: Wait behind submissions already in the queue
    Given I am signed in as a "Free" member
    And the judge queue contains 9 Pending submissions
    When I submit a correct Ruby solution for "contains-duplicate"
    Then I see a Pending result with 9 submissions ahead and an estimated wait of 541 seconds

  Scenario: Keep my code when the judge queue is full
    Given I am signed in as a "Free" member
    And the judge queue contains 10 Pending submissions
    When I submit a correct Ruby solution for "contains-duplicate"
    Then I am told when to retry without losing my code

  Scenario Outline: Recover from a Ruby submission failure
    Given I am signed in as a "Free" member
    When I submit a Ruby solution with "<failure>"
    Then I first see a "Pending" result
    When judging finishes
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

  Scenario: Reject an unsupported language at the server
    Given I am signed in as a "Free" member
    When I try to submit a solution labelled "javascript"
    Then the page explains that the language is not supported
    And no submission has been created

  Scenario: Save my code when the remote judge cannot be reached
    Given I am signed in as a "Free" member
    And the remote judge cannot be reached
    When I submit a correct Ruby solution for "contains-duplicate"
    Then I first see a "Pending" result
    When judging finishes
    Then I see the "Judge Unavailable" verdict and a passed-case count
    And my submitted code is preserved in my personal history

  Scenario: Judge a Go submission through a Heroku one-off dyno
    Given I am signed in as a "Free" member
    And Heroku can create an isolated one-off judge dyno
    When I submit a correct "go" solution for "contains-duplicate"
    Then I first see a "Pending" result
    When judging finishes
    Then I see an "Accepted" result with every predefined case passed
    And the submission shows "Go 1.27.3"

  Scenario: Keep an empty Ruby submission in my history
    Given I am signed in as a "Free" member
    When I submit an empty Ruby solution
    Then I first see a "Pending" result
    When judging finishes
    Then I see the "Runtime Error" verdict and a passed-case count
    And the page explains that code is required
    And my submitted code is preserved in my personal history
    And I can retry with the problem's starter code

  Scenario: Use an already-ready judge and prepare a fresh replacement
    Given I am signed in as a "Free" member
    And two unused Heroku judges are ready
    When I submit a correct Ruby solution for "contains-duplicate"
    Then I first see a "Pending" result
    When judging finishes
    Then I see an "Accepted" result with every predefined case passed
    And my judge is retired and two unused judges become ready

  Scenario: Preserve a submission when a ready judge returns an invalid result
    Given I am signed in as a "Free" member
    And a ready Heroku judge will return an invalid result
    When I submit a correct Ruby solution for "contains-duplicate"
    When judging finishes
    Then I see the "Judge Unavailable" verdict and a passed-case count
    And my submitted code is preserved in my personal history
    And my judge is retired and two unused judges become ready

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
