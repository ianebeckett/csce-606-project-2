require "rails_helper"

RSpec.describe "Learning history models" do
  before { seed_judge }

  let(:user) { create_user }

  def create_attempt(owner, problem, result)
    owner.practice_sessions.for_today(problem).attempts.create!(
      code: problem.starter_code,
      judge_result: result
    )
  end

  it "associates messages with attempts and exposes only a user's messages" do
    problem = Problem.first
    own_attempt = create_attempt(user, problem, Attempt::ACCEPTED)
    other_attempt = create_attempt(create_user(email: "other@example.com"), problem, Attempt::ACCEPTED)
    own_message = own_attempt.practice_session.conversation_messages.create!(role: "assistant", content: "Looks good.")
    other_attempt.practice_session.conversation_messages.create!(role: "user", content: "Help.")

    expect(user.conversation_messages).to contain_exactly(own_message)
  end

  it "associates review schedules with their user, problem, and topic" do
    problem = Problem.first
    schedule = user.review_schedules.create!(problem: problem, scheduled_for: Date.current)

    expect(schedule.user).to eq(user)
    expect(schedule.problem).to eq(problem)
    expect(problem.review_schedules).to contain_exactly(schedule)
    expect(problem.topic.review_schedules).to contain_exactly(schedule)
  end

  it "counts distinct solved problems and only the user's review schedules" do
    first_problem, second_problem = Problem.first(2)
    create_attempt(user, first_problem, Attempt::ACCEPTED)
    create_attempt(user, first_problem, Attempt::ACCEPTED)
    create_attempt(user, second_problem, Attempt::WRONG_ANSWER)

    other_user = create_user(email: "other@example.com")
    create_attempt(other_user, second_problem, Attempt::ACCEPTED)
    user.review_schedules.create!(problem: first_problem, scheduled_for: Date.current)
    other_user.review_schedules.create!(problem: second_problem, scheduled_for: Date.current)

    expect(user.solved_problem_ids).to eq([ first_problem.id ])
    expect(user.solved_count).to eq(1)
    expect(user.review_count).to eq(1)
  end

  it "reports solved and total problem counts for each topic" do
    problem = Problem.first
    create_attempt(user, problem, Attempt::ACCEPTED)
    other_user = create_user(email: "other@example.com")
    create_attempt(other_user, Problem.second, Attempt::ACCEPTED)

    progress = user.topic_progress.index_by { |entry| entry[:topic].id }

    expect(progress.fetch(problem.topic.id)).to include(solved_count: 1, total_count: 1)
    expect(progress.fetch(Problem.second.topic.id)).to include(solved_count: 0, total_count: 1)
  end

  it "requires a scheduled date for review schedules" do
    expect(user.review_schedules.new(problem: Problem.first)).not_to be_valid
  end
end
