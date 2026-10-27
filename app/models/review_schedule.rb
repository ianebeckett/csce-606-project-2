class ReviewSchedule < ApplicationRecord
  belongs_to :user
  belongs_to :problem

  # Every schedule must have a review date, at least 1 day
  validates :next_review_date, presence: true
  validates :interval_days,
            numericality: { only_integer: true, greater_than: 0 }
  validates :problem_id, uniqueness: { scope: :user_id }
  scope :due, -> {
    where("next_review_date <= ?", Date.current)
  }

  # Update the review schedule using a performance rating
  # 1 -Very difficult: review again tomorrow
  # 2 - Difficult: review again in 2 days
  # 3 - Moderate: keep the current interval
  # 4- Easy: double the interval
  # 5- Very easy: triple the interval
  def update_from_rating!(rating:)
    case rating
    when 1
      self.interval_days = 1
    when 2
      self.interval_days = 2
    when 3
      self.interval_days = interval_days
    when 4
      self.interval_days *= 2
    when 5
      self.interval_days *= 3
    else
      raise ArgumentError, "Rating must be between 1 and 5"
    end

    self.next_review_date = Date.current + interval_days.days
    save!
  end
end
