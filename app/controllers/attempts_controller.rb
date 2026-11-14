class AttemptsController < ApplicationController
  include RoadmapAccess

  HISTORY_LIMIT = 100
  COACHING_LOCKED_MESSAGE = "Explain your approach to the coach before submitting code.".freeze

  def index
    @attempts = current_user.attempts.includes(practice_session: :problem).order(created_at: :desc).limit(HISTORY_LIMIT)
  end

  def show
    @attempt = current_user.attempts.includes(practice_session: :problem).find(params[:id])
    # Polled by the submission page while judging, so it can update itself.
    return render(json: { judge_result: @attempt.judge_result, pending: @attempt.judge_result == Attempt::PENDING }) if request.format.json?

    if @attempt.judge_result == Attempt::PENDING && !@attempt.judging_started_at
      @queue_wait = Judge::Queue.new.wait_for(@attempt)
    end
  end

  def create
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:problem_id])
    return unless require_unlocked_topic(@problem.topic)
    return redirect_to(problem_path(@problem), alert: COACHING_LOCKED_MESSAGE) if coaching_locked?

    @attempt = Attempt.new(params.require(:attempt).permit(:code, :language))
    @language = Attempt::LANGUAGES.include?(@attempt.language) ? @attempt.language : Attempt::LANGUAGE

    unless @problem.ready_for_judging?
      @attempt.errors.add(:base, "This problem is not ready for judging: at least five cases are required.")
      return render "problems/show", status: :unprocessable_content
    end

    @attempt.practice_session = current_user.practice_sessions.for_today(@problem)
    @attempt.total_cases = @problem.test_cases.size
    if Judge::Queue.new.submit(@attempt)
      redirect_to attempt_path(@attempt)
    else
      render "problems/show", status: :unprocessable_content
    end
  rescue Judge::Queue::Full => error
    response.set_header("Retry-After", error.retry_after.to_s)
    @attempt.errors.add(:base, error.message)
    render "problems/show", status: :service_unavailable
  end

  private

  # Checked on the server so a hidden editor can't be bypassed with a direct POST.
  def coaching_locked?
    current_user.premium? && current_user.practice_sessions.for_today(@problem).coaching_locked?
  end
end
