
class PracticeSessionRatingsController < ApplicationController
  def update
    practice = current_user.practice_sessions.find(params[:id])

    # Read and validate the student's performance rating.
    rating = Integer(params[:review_rating], exception: false)
    unless (1..5).cover?(rating)
      return redirect_to problems_path, alert: "Select a rating from 1 to 5."
    end

    attempt = practice.attempts.find_by(id: params[:attempt_id])
    latest_attempt = practice.attempts.order(created_at: :desc, id: :desc).first

    # Only allow the most recent completed attempt to be rated.
    unless attempt && attempt.id == latest_attempt&.id
      return redirect_to problems_path, alert: "Only the latest attempt can be rated."
    end

    unless [ Attempt::ACCEPTED, Attempt::WRONG_ANSWER ].include?(attempt.judge_result)
      return redirect_to problems_path, alert: "Complete a coding attempt first."
    end

    if practice.review_scheduled_at.present? &&
       attempt.created_at <= practice.review_scheduled_at
      return redirect_to problems_path, alert: "This attempt has already been rated."
    end

    # Save the rating and review schedule together.
    schedule = PracticeSession.transaction do
      practice.update!(
        status: "completed",
        completed_at: Time.current,
        review_rating: rating
      )

      ReviewScheduler.call(practice)
    end

    # Generate AI feedback only for Premium members.
    if current_user.premium?
      begin
        feedback = Coaching::SessionFeedback.new(client: Ai.client).call(practice)
        practice.update!(feedback_summary: feedback.to_json)
      rescue Coaching::Error => e
        Rails.logger.error("Session feedback generation failed: #{e.message}")
      end
    end

    # Confirm completion and show the next scheduled review date.
    redirect_to attempt_path(attempt),
                notice: "Next review scheduled for #{schedule.next_review_date}."
  end
end
