class AttemptsController < ApplicationController
  include RoadmapAccess

  HISTORY_LIMIT = 100

  def index
    @attempts = current_user.attempts.includes(practice_session: :problem).order(created_at: :desc).limit(HISTORY_LIMIT)
  end

  def show
    @attempt = current_user.attempts.includes(practice_session: :problem).find(params[:id])
  end

  def create
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:problem_id])
    return unless require_unlocked_topic(@problem.topic)

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
end
