class ProblemsController < ApplicationController
  include RoadmapAccess

  def index
    @topic = Topic.find(params[:topic]) if params[:topic].present?
    return if @topic && !require_unlocked_topic(@topic)

    available_topics = @topic || roadmap.topics.select { |topic| roadmap.unlocked?(topic) }
    @problems = Problem.includes(:topic).joins(:topic).where(topic: available_topics).order("topics.position", :title)
  end

  def show
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:id])
    return unless require_unlocked_topic(@problem.topic)

    previous = current_user.attempts.joins(:practice_session).where(practice_sessions: { problem_id: @problem.id })
      .order(created_at: :desc, id: :desc).first
    @attempt = Attempt.new(code: previous&.code || @problem.starter_code, language: Attempt::LANGUAGE)
  end
end
