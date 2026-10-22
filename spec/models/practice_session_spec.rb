require "rails_helper"

RSpec.describe PracticeSession do
  include ActiveSupport::Testing::TimeHelpers

  before { seed_judge }
  let(:user) { create_user }
  let(:problem) { Problem.first }

  it "creates today's session and reuses it regardless of completion status" do
    travel_to(Time.utc(2026, 10, 21, 4, 59, 59)) do
      session = user.practice_sessions.for_today(problem)
      expect(session.practice_date).to eq(Date.new(2026, 10, 20))
      expect(session.started_at).to eq(Time.current)
      session.update!(status: "completed", completed_at: Time.current, feedback_summary: "Saved feedback")
      original = session.attributes

      expect { expect(user.practice_sessions.for_today(problem)).to eq(session) }.not_to change(described_class, :count)
      expect(session.reload.attributes).to eq(original)
    end
  end

  it "starts a new session at Chicago midnight without completing yesterday's session" do
    travel_to(Time.utc(2026, 10, 21, 4, 59, 59)) do
      yesterday = user.practice_sessions.for_today(problem)
      original = yesterday.attributes
      travel 1.second
      today = user.practice_sessions.for_today(problem)

      expect(today).not_to eq(yesterday)
      expect(today.practice_date).to eq(Date.new(2026, 10, 21))
      expect(yesterday.reload.attributes).to eq(original)
    end
  end

  it "separates users and problems and rejects duplicate dates in the database" do
    session = user.practice_sessions.for_today(problem)
    other_user = create_user(email: "other@example.com")
    expect(other_user.practice_sessions.for_today(problem)).not_to eq(session)
    expect(user.practice_sessions.for_today(Problem.second)).not_to eq(session)
    expect do
      user.practice_sessions.create!(problem: problem, started_at: Time.current)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
