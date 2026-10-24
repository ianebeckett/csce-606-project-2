class CodeReviewsController < ApplicationController
  UNAVAILABLE_MESSAGE = "AI code review is unavailable right now. Your code is saved, so please try again later.".freeze

  before_action :set_attempt
  before_action :require_premium
  before_action :require_code

  def create
    @review = CodeReview::Reviewer.new(client: Ai.client).call(
      code: @attempt.code, language: @attempt.language, problem: @attempt.problem.description,
      judge_result: "#{@attempt.judge_result} (#{@attempt.passed_cases}/#{@attempt.total_cases} test cases passed)")
    render :show
  rescue CodeReview::Error => e
    Rails.logger.warn("AI code review failed for attempt #{@attempt.id}: #{e.message}")
    redirect_to attempt_path(@attempt), alert: UNAVAILABLE_MESSAGE
  end

  private

  def set_attempt
    @attempt = current_user.attempts.includes(practice_session: :problem).find(params[:attempt_id])
  end

  def require_code
    redirect_to attempt_path(@attempt), alert: "There's no code to review yet." if @attempt.code.blank?
  end

  def require_premium
    redirect_to attempt_path(@attempt), alert: "AI code review is a Premium feature." unless current_user.premium?
  end
end
