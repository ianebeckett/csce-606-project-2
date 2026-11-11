module InterviewHelper
  STEP_HINTS = {
    "clarifying" => "Ask clarifying questions. The full problem appears once you've found the missing details.",
    "strategy" => "Describe your high-level strategy. Don't write code yet.",
    "twist" => "The requirements changed. Explain how you would adapt your approach. The editor unlocks once you do.",
    "coding" => "The editor is unlocked. Write your solution, or keep talking to the interviewer.",
    "skipped" => "The interviewer was unavailable, so the editor is unlocked. You can still send messages."
  }.freeze

  def interview_step_hint(practice_session)
    STEP_HINTS.fetch(practice_session.interview_state)
  end
end
