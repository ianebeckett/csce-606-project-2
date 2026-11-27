Feature: US5 — Post-Session Feedback
  As a learner
  I want feedback on my coaching session
  So that I know how to improve my problem solving and explanations

  Background:
    Given the six requested Easy problems are available

  Scenario: A learner receives AI feedback after completing a coaching session
    Given I am signed in as a "Premium" member
    And I have a coaching conversation for "Contains Duplicate"
    And AI feedback is available
    When I complete practice with a rating of 4
    Then I see my post-session feedback
    And I see feedback about conceptual accuracy
    And I see feedback about explanation quality
    And I see actionable improvement tips

  Scenario: Practice completion succeeds when AI feedback is unavailable
    Given I am signed in as a "Premium" member
    And I have a coaching conversation for "Contains Duplicate"
    And AI feedback is unavailable
    When I complete practice with a rating of 4
    Then my practice session is completed
    And my next review is scheduled
    And no post-session feedback is displayed

  Scenario: The AI client reports when no provider is configured
    When I call the unconfigured AI client
    Then it raises the missing AI provider error