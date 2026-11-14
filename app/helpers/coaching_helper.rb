module CoachingHelper
  STEP_HINTS = {
    "problem" => "Step 1 of 3: Before you code, explain the problem in your own words.",
    "approach" => "Step 2 of 3: Explain your approach. The editor unlocks once it is correct.",
    "complexity" => "Step 3 of 3: The editor is unlocked. Discuss the time and space complexity, or start coding.",
    "skipped" => "The coach was unavailable, so the editor is unlocked. You can still send messages."
  }.freeze

  STAGE_LABELS = {
    "problem" => "Restate the problem",
    "approach" => "Explain your approach",
    "complexity" => "Discuss complexity"
  }.freeze

  STAGE_PASSED_MESSAGES = {
    "problem" => "Stage 1 passed: you understand the problem. Next, explain your approach.",
    "approach" => "Stage 2 passed: your approach works. The editor is unlocked."
  }.freeze

  # The stage that changes the editor from locked to unlocked once passed.
  UNLOCKING_STAGE = "approach".freeze

  def coaching_step_hint(practice_session)
    STEP_HINTS.fetch(practice_session.coaching_state)
  end

  # "done", "current", or "upcoming" for one stage of the progress tracker.
  def coaching_stage_status(practice_session, stage)
    stages = PracticeSession::COACHING_STAGES
    current = stages.index(practice_session.coaching_state)
    position = stages.index(stage)
    return "done" if position < current
    return "current" if position == current

    "upcoming"
  end

  def coaching_stage_passed_message(stage)
    STAGE_PASSED_MESSAGES[stage]
  end

  def editor_just_unlocked?
    flash[:coaching_stage_passed] == UNLOCKING_STAGE
  end
end
