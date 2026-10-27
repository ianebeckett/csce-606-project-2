
class PracticeSessionRatingsController < ApplicationController
  def update
    practice = current_user.practice_sessions.find(params[:id])

    # Read the student's performance rating
    rating = Integer(params[:review_rating], exception: false)
    unless (1..5).cover?(rating)
      return redirect_to problems_path, alert: "Select a rating from 1 to 5."
    end
    if practice.status == "completed"
      return redirect_to problems_path, alert: "This session is already completed."
    end
    valid_attempt = practice.attempts.where(
      judge_result: [ Attempt::ACCEPTED, Attempt::WRONG_ANSWER ]
    ).exists?

    unless valid_attempt
      return redirect_to problems_path, alert: "Complete a coding attempt first."
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
