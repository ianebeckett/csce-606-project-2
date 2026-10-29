
class ReviewScheduler
  def self.call(practice_session)
    practice_session.user.with_lock do
      practice_session.with_lock do
        unless practice_session.status == "completed" &&
               practice_session.completed_at.present? &&
               practice_session.review_rating.present?
          raise ArgumentError, "Session must be completed and rated"
        end

        schedule = ReviewSchedule.find_or_initialize_by(
          user: practice_session.user,
          problem: practice_session.problem
        )
        base_interval = practice_session.review_base_interval_days ||
                        schedule.interval_days || 1

        practice_session.review_base_interval_days = base_interval
        schedule.interval_days = base_interval
        schedule.update_from_rating!(
          rating: practice_session.review_rating
        )
        practice_session.update!(
          review_scheduled_at: Time.current
        )

        schedule
      end
    end
  end
end
