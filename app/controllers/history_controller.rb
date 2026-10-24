class HistoryController < ApplicationController
  def index
    @attempts = current_user.attempts.includes(
      :conversation_messages,
      practice_session: { problem: :topic }
    ).order(created_at: :desc)
    @solved_count = current_user.solved_count
    @review_count = current_user.review_count
    @topic_progress = current_user.topic_progress
  end

  def show
    @attempt = current_user.attempts.includes(
      :conversation_messages,
      practice_session: { problem: :topic }
    ).find(params[:id])
  end
end
