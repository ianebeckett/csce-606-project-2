class AttemptsController < ApplicationController
  include RoadmapAccess

  HISTORY_LIMIT = 100
  COACHING_LOCKED_MESSAGE = "Explain your approach to the coach before submitting code.".freeze

  def index
    @attempts = current_user.attempts.includes(practice_session: :problem).order(created_at: :desc).limit(HISTORY_LIMIT)
  end

  def show
    @attempt = current_user.attempts.includes(practice_session: :problem).find(params[:id])
  end

  def create
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:problem_id])
    return unless require_unlocked_topic(@problem.topic)
    return redirect_to(problem_path(@problem), alert: COACHING_LOCKED_MESSAGE) if coaching_locked?

    @attempt = Attempt.new(params.require(:attempt).permit(:code, :language))

    unless @problem.ready_for_judging?
      @attempt.errors.add(:base, "This problem is not ready for judging: at least five cases are required.")
      return render "problems/show", status: :unprocessable_content
    end

    @attempt.practice_session = current_user.practice_sessions.for_today(@problem)
    if @attempt.save
      Judge::Submission.new.call(@attempt)
      redirect_to attempt_path(@attempt)
    else
      render "problems/show", status: :unprocessable_content
    end
  end

  private

  # Checked on the server so a hidden editor can't be bypassed with a direct POST.
  def coaching_locked?
    current_user.premium? && current_user.practice_sessions.for_today(@problem).coaching_locked?
  end
end
