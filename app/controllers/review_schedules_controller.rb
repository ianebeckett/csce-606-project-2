
class ReviewSchedulesController < ApplicationController
  def index
    # Get all upcoming reviews for the logged-in student
    @upcoming_reviews = current_user.review_schedules
                                    .where("next_review_date > ?", Date.current)
                                    .includes(:problem)
                                    .order(:next_review_date)
  end
end
