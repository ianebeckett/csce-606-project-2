class ProblemRestartsController < ApplicationController
  include RoadmapAccess

  def create
    problem = Problem.find_by!(slug: params[:problem_id])
    return unless require_unlocked_topic(problem.topic)

    current_user.practice_sessions.for_today(problem).restart_coaching!
    redirect_to problem_path(problem, fresh: 1), notice: "Starting over. Your past submissions are still in My submissions."
  end
end
