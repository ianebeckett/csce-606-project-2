class CoachingMessagesController < ApplicationController
  include RoadmapAccess

  before_action :set_problem
  before_action :require_premium

  def create
    @practice_session = current_user.practice_sessions.for_today(@problem)
    message = @practice_session.conversation_messages.new(role: "user", content: params.require(:conversation_message)[:content])
    return redirect_to(problem_path(@problem), alert: message.errors.full_messages.to_sentence) unless message.save

    reply = Coaching::Coach.new(client: Ai.client).call(@practice_session)
    @practice_session.conversation_messages.create!(role: "assistant", content: reply.message)
    @practice_session.advance_coaching! if reply.advance
    redirect_to problem_path(@problem)
  rescue Coaching::Error => e
    Rails.logger.warn("Coaching failed for practice session #{@practice_session.id}: #{e.message}")
    @practice_session.skip_coaching!
    redirect_to problem_path(@problem),
      alert: "#{@practice_session.coach_name} is unavailable right now. Your message is saved, and the editor is unlocked."
  end

  private

  def set_problem
    @problem = Problem.find_by!(slug: params[:problem_id])
    require_unlocked_topic(@problem.topic)
  end

  def require_premium
    redirect_to problem_path(@problem), alert: "The coach is a Premium feature." unless current_user.premium?
  end
end
