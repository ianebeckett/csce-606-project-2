class ProblemsController < ApplicationController
  include RoadmapAccess

  def index
    @topic = Topic.find(params[:topic]) if params[:topic].present?
    return if @topic && !require_unlocked_topic(@topic)

    available_topics = @topic || roadmap.topics.select { |topic| roadmap.unlocked?(topic) }
    @problems = Problem.includes(:topic).joins(:topic).where(topic: available_topics).order("topics.position", :title)

    # Get the logged-in student's reviews due today or earlier
    @due_reviews = current_user.review_schedules.due
                               .includes(:problem)
                               .order(:next_review_date)
  end

  def show
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:id])
    return unless require_unlocked_topic(@problem.topic)

    previous = current_user.attempts.joins(:practice_session).where(practice_sessions: { problem_id: @problem.id })
      .order(created_at: :desc, id: :desc).first
    @attempt = Attempt.new(code: previous&.code.presence || @problem.starter_code, language: Attempt::LANGUAGE)
    @coaching_session = current_user.practice_sessions.for_today(@problem) if current_user.premium?
  end
end
