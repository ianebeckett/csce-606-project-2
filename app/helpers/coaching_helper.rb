module CoachingHelper
  STEP_HINTS = {
    "problem" => "Step 1 of 3: Before you code, explain the problem in your own words.",
    "approach" => "Step 2 of 3: Explain your approach. The editor unlocks once it is correct.",
    "complexity" => "Step 3 of 3: The editor is unlocked. Discuss the time and space complexity, or start coding.",
    "skipped" => "The coach was unavailable, so the editor is unlocked. You can still send messages."
  }.freeze

  # The stage that changes the editor from locked to unlocked once passed.
  UNLOCKING_STAGE = "approach".freeze

  def coaching_step_hint(practice_session)
    STEP_HINTS.fetch(practice_session.coaching_state)
  end

  def coaching_stage_just_passed?
    flash[:coaching_stage_passed].present?
  end

  def editor_just_unlocked?
    flash[:coaching_stage_passed] == UNLOCKING_STAGE
  end
end
