
class ReviewSchedulesController < ApplicationController
  def index
    # Get only the logged-in student's review schedules
    @due_reviews = current_user.review_schedules.due
                               .includes(:problem)
                               .order(:next_review_date)
  end
end
