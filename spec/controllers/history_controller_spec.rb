require "rails_helper"

RSpec.describe HistoryController, type: :controller do
  before do
    seed_judge
    allow(controller).to receive(:default_render)
  end

  let(:user) { create_user }

  def create_attempt(owner, problem, result: Attempt::PENDING)
    owner.practice_sessions.for_today(problem).attempts.create!(
      code: problem.starter_code,
      judge_result: result
    )
  end

  it "requires login for both history actions" do
    get :index
    expect(response).to redirect_to(new_session_path)

    get :show, params: { id: 1 }
    expect(response).to redirect_to(new_session_path)
  end

  User::ROLES.each do |role|
    it "allows #{role} members to view their history" do
      member = create_user(role: role)
      attempt = create_attempt(member, Problem.first, result: Attempt::ACCEPTED)
      member.review_schedules.create!(problem: Problem.first, scheduled_for: Date.current)
      session[:user_id] = member.id

      get :index

      expect(response).to have_http_status(:ok)
      expect(controller.view_assigns["attempts"]).to contain_exactly(attempt)
      expect(controller.view_assigns["solved_count"]).to eq(1)
      expect(controller.view_assigns["review_count"]).to eq(1)
      expect(controller.view_assigns["topic_progress"]).to be_present

      get :show, params: { id: attempt.id }

      expect(response).to have_http_status(:ok)
      expect(controller.view_assigns["attempt"]).to eq(attempt)
    end
  end

  it "limits the index and show action to the signed-in user's attempts" do
    own_attempt = create_attempt(user, Problem.first)
    other_attempt = create_attempt(create_user(email: "other@example.com"), Problem.second)
    session[:user_id] = user.id

    get :index
    expect(controller.view_assigns["attempts"]).to contain_exactly(own_attempt)

    expect do
      get :show, params: { id: other_attempt.id }
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "returns an empty collection and zero counts when the user has no history" do
    session[:user_id] = user.id

    get :index

    expect(response).to have_http_status(:ok)
    expect(controller.view_assigns["attempts"]).to be_empty
    expect(controller.view_assigns["solved_count"]).to eq(0)
    expect(controller.view_assigns["review_count"]).to eq(0)
  end
end
