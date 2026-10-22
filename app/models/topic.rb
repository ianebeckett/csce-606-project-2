class Topic < ApplicationRecord
  has_many :problems, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
[]
