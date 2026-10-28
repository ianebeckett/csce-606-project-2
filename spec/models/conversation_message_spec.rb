require "rails_helper"

RSpec.describe ConversationMessage do
  include CodeReviewHelpers

  before { seed_judge }

  let(:user) { create_user(email: "p@example.com", role: "Premium") }
  let(:session) { user.practice_sessions.create!(problem: Problem.first, started_at: Time.current) }

  it "belongs to a session and needs no attempt" do
    message = session.conversation_messages.new(role: "user", content: "Use a hash set.")
    expect(message).to be_valid
  end

  it "only accepts user or assistant as the role" do
    expect(session.conversation_messages.new(role: "user", content: "hi")).to be_valid
    expect(session.conversation_messages.new(role: "assistant", content: "hi")).to be_valid
    expect(session.conversation_messages.new(role: "robot", content: "hi")).not_to be_valid
  end

  it "needs non-blank content" do
    expect(session.conversation_messages.new(role: "user", content: " ")).not_to be_valid
  end

  it "accepts an attempt from its own session but not from another" do
    own = session.attempts.create!(code: "def x; end", language: "ruby")
    other_session = user.practice_sessions.create!(problem: Problem.last, started_at: 2.days.ago)
    foreign = other_session.attempts.create!(code: "def y; end", language: "ruby")

    expect(session.conversation_messages.new(role: "user", content: "hi", attempt: own)).to be_valid
    expect(session.conversation_messages.new(role: "user", content: "hi", attempt: foreign)).not_to be_valid
  end
end
