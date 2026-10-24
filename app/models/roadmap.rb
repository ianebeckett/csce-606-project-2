class Roadmap
  attr_reader :topics, :solved_ids

  def initialize(user)
    @topics = Topic.includes(:problems, :prerequisites).order(:position, :id).to_a
    @topics_by_id = @topics.index_by(&:id)
    @solved_ids = user.solved_problem_ids
    @states = {}
  end

  def state(topic)
    topic = @topics_by_id.fetch(topic.id)
    @states[topic.id] ||= if topic.prerequisites.any? { |prerequisite| state(prerequisite) != "Mastered" }
      "Locked"
    elsif topic.problems.any? && topic.problems.all? { |problem| solved_ids.include?(problem.id) }
      "Mastered"
    else
      "In Progress"
    end
  end

  def unlocked?(topic)
    state(topic) != "Locked"
  end
end
