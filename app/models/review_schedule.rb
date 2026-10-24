class ReviewSchedule < ApplicationRecord
  # Each review schedule belongs to one student, one problem
  belongs_to :user
  belongs_to :problem

  # Every schedule must have a review date, at least 1 day
  validates :next_review_date, presence: true
  validates :interval_days,
            numericality: { only_integer: true, greater_than: 0 }

  # Prevent duplicate schedules for the same student and problem
  validates :problem_id, uniqueness: { scope: :user_id }

  # Find all reviews that are due today or overdue
  scope :due, -> {
    where("next_review_date <= ?", Date.current)
  }

  # Update the next review date based on student performance
  def update_review!(successful:)
    if successful
      self.interval_days *= 2 # Double the interval after a successful review
    else
      self.interval_days = 1
    end

    # Calculate the next review date
    self.next_review_date = Date.current + interval_days.days
    save!
  end
end