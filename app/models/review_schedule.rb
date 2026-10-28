class ReviewSchedule < ApplicationRecord
  belongs_to :user
  belongs_to :problem

  validates :scheduled_for, presence: true
end
