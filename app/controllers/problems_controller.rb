class ProblemsController < ApplicationController
  PRACTICE_SET_SIZE = 6

  def index
    @topics = Topic.order(:position)
    @problems = Problem.includes(:topic, :test_cases).joins(:topic).order("topics.position")
    @problems = @problems.where(topic_id: params[:topic]) if params[:topic].present?
    @solved_ids = current_user.attempts.where(judge_result: Attempt::ACCEPTED).joins(:practice_session)
      .distinct.pluck("practice_sessions.problem_id")
  end

  def show
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:id])
    previous = current_user.attempts.joins(:practice_session).where(practice_sessions: { problem_id: @problem.id })
      .order(created_at: :desc, id: :desc).first
    @attempt = Attempt.new(code: previous&.code || @problem.starter_code, language: Attempt::LANGUAGE)
  end
end
