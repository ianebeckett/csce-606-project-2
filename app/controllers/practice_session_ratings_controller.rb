
class PracticeSessionRatingsController < ApplicationController
  def update
    practice = current_user.practice_sessions.find(params[:id])
    # Read the student's performance rating
    rating = Integer(params[:review_rating], exception: false)
    unless (1..5).cover?(rating)
      return redirect_to problems_path, alert: "Select a rating from 1 to 5."
    end

    attempt = practice.attempts.find_by(id: params[:attempt_id])
    latest_attempt = practice.attempts.order(created_at: :desc, id: :desc).first

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

    # Save the rating and review schedule together
    schedule = PracticeSession.transaction do
      practice.update!(
        status: "completed",
        completed_at: Time.current,
        review_rating: rating
      )

      ReviewScheduler.call(practice)
    end

    # Show confirmation with the saved review date
    redirect_to problems_path,
                notice: "Next review scheduled for #{schedule.next_review_date}."
  end
end
