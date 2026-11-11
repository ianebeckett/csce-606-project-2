module InterviewAccess
  extend ActiveSupport::Concern

  included do
    include RoadmapAccess

    before_action :set_problem
    before_action :require_premium
  end

  private

  def set_problem
    @problem = Problem.find_by!(slug: params[:problem_id])
    raise ActiveRecord::RecordNotFound unless @problem.interview_ready?

    require_unlocked_topic(@problem.topic)
  end

  def require_premium
    redirect_to problem_path(@problem), alert: "The interviewer is a Premium feature." unless current_user.premium?
  end
end
