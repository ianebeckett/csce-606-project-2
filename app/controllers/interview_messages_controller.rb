class InterviewMessagesController < ApplicationController
  include InterviewAccess

  def create
    @practice_session = current_user.practice_sessions.for_today(@problem)
    @practice_session.start_interview!
    message = @practice_session.conversation_messages.new(
      role: "user", phase: "interview", content: params.require(:conversation_message)[:content])
    return redirect_to(problem_interview_path(@problem), alert: message.errors.full_messages.to_sentence) unless message.save

    reply = Interviewing::Interviewer.new(client: Ai.client).call(@practice_session)
    @practice_session.conversation_messages.create!(role: "assistant", phase: "interview", content: reply.message)
    @practice_session.advance_interview! if reply.advance
    redirect_to problem_interview_path(@problem)
  rescue Coaching::Error => e
    Rails.logger.warn("Interview failed for practice session #{@practice_session.id}: #{e.message}")
    @practice_session.skip_interview!
    redirect_to problem_interview_path(@problem),
      alert: "The interviewer is unavailable right now. Your message is saved, and the editor is unlocked."
  end
end
