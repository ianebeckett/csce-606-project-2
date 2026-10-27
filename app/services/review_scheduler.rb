
class ReviewScheduler
  def self.call(practice_session)
    # Lock the user to prevent overlapping review updates
    practice_session.user.with_lock do
      practice_session.with_lock do
        if practice_session.review_scheduled_at.present?
          ReviewSchedule.find_by!(
            user: practice_session.user,
            problem: practice_session.problem
          )
        else
          unless practice_session.status == "completed" &&
                 practice_session.completed_at.present? &&
                 practice_session.review_rating.present?
            raise ArgumentError, "Session must be completed and rated"
          end
          schedule = ReviewSchedule.find_or_initialize_by(
            user: practice_session.user,
            problem: practice_session.problem
          )

          # Start new schedules with a one-day interval
          schedule.interval_days ||= 1
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
end
