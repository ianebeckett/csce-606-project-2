require "rails_helper"

RSpec.describe PracticeSession, "interview stages" do
  before { seed_judge }
  let(:user) { create_user }
  let(:problem) { Problem.first }
  let(:session) { user.practice_sessions.for_today(problem) }

  def interview_twists
    session.conversation_messages.interview.where(role: "assistant", content: problem.interview_twist)
  end

  it "starts not_started and locked" do
    expect(session.interview_state).to eq("not_started")
    expect(session).to be_interview_locked
    expect(session).not_to be_interview_clarified
  end

  it "start_interview! moves to clarifying once" do
    2.times { session.start_interview! }
    expect(session.reload.interview_state).to eq("clarifying")
  end

  it "advances clarifying -> strategy -> twist -> coding" do
    session.start_interview!
    expect(session).not_to be_interview_clarified
    session.advance_interview!
    expect(session.interview_state).to eq("strategy")
    expect(session).to be_interview_clarified
    session.advance_interview!
    expect(session.interview_state).to eq("twist")
    expect(session).to be_interview_locked
    session.advance_interview!
    expect(session.interview_state).to eq("coding")
    expect(session).not_to be_interview_locked
  end

  it "posts the twist exactly once on entering twist" do
    session.start_interview!
    3.times { session.advance_interview! }
    session.advance_interview!
    expect(interview_twists.count).to eq(1)
  end

  it "does not move from not_started, coding or skipped" do
    session.advance_interview!
    expect(session.interview_state).to eq("not_started")
    session.update!(interview_state: "coding")
    session.advance_interview!
    expect(session.interview_state).to eq("coding")
    session.update!(interview_state: "skipped")
    session.advance_interview!
    expect(session.interview_state).to eq("skipped")
  end

  it "skip_interview! unlocks and is a no-op once coding" do
    session.start_interview!
    session.skip_interview!
    expect(session.reload.interview_state).to eq("skipped")
    expect(session).not_to be_interview_locked
    expect(session).to be_interview_clarified

    other = user.practice_sessions.create!(problem: Problem.second, started_at: Time.current, interview_state: "coding")
    other.skip_interview!
    expect(other.interview_state).to eq("coding")
  end

  it "skip_interview! from a locked coach moves it to complexity" do
    session.update!(coaching_state: "problem")
    session.start_interview!
    session.skip_interview!
    expect(session.reload.coaching_state).to eq("complexity")
  end

  it "reveals the twist only from the twist stage on" do
    expect(%w[not_started clarifying strategy].map { |s| described_class.new(interview_state: s).interview_twist_revealed? }).to all(be false)
    expect(%w[twist coding skipped].map { |s| described_class.new(interview_state: s).interview_twist_revealed? }).to all(be true)
  end

  it "finishing moves a locked coach to complexity, not skipped" do
    session.update!(coaching_state: "problem")
    session.start_interview!
    3.times { session.advance_interview! }
    expect(session.reload.coaching_state).to eq("complexity")
  end

  it "finishing leaves an unlocked coach alone" do
    session.update!(coaching_state: "skipped")
    session.start_interview!
    3.times { session.advance_interview! }
    expect(session.reload.coaching_state).to eq("skipped")
  end
end
