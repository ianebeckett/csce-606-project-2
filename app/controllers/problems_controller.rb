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

    @due_reviews_count = @due_reviews.count
    @due_reviews = @due_reviews.limit(2)

    # Get the student's upcoming reviews
    @upcoming_reviews = current_user.review_schedules
                                    .includes(:problem)
                                    .where("next_review_date > ?", Date.current)
                                    .order(:next_review_date)
    @upcoming_reviews_preview = @upcoming_reviews.limit(2)
  end

  def show
    @problem = Problem.includes(:test_cases).find_by!(slug: params[:id])
    return unless require_unlocked_topic(@problem.topic)

    attempts = current_user.attempts.joins(:practice_session).where(practice_sessions: { problem_id: @problem.id })
    latest = attempts.order(created_at: :desc, id: :desc).first
    requested = params[:language].presence || latest&.language || Attempt::LANGUAGE
    @language = Attempt::LANGUAGES.include?(requested) ? requested : Attempt::LANGUAGE
    previous = attempts.where(language: @language).order(created_at: :desc, id: :desc).first
    code = previous&.code.presence || @problem.starter_code_for(@language)
    @attempt = Attempt.new(code: code, language: @language)
    @coaching_session = current_user.practice_sessions.for_today(@problem) if current_user.premium?
  end
end
