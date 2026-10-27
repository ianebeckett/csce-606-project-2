class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 12
  ROLES = %w[Free Premium].freeze

  has_secure_password
  has_many :practice_sessions, dependent: :destroy
  has_many :attempts, through: :practice_sessions
  has_many :review_schedules, dependent: :destroy # student has multiple scheduled reviews

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
  validates :role, inclusion: { in: ROLES }

  def premium?
    role == "Premium"
  end
end
