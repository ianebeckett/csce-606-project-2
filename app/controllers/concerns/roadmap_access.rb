module RoadmapAccess
  extend ActiveSupport::Concern

  included { helper_method :roadmap }

  private

  def roadmap
    @roadmap ||= Roadmap.new(current_user)
  end

  def require_unlocked_topic(topic)
    return true if roadmap.unlocked?(topic)

    render "problems/locked", locals: { topic: topic }, status: :forbidden
    false
  end
end
