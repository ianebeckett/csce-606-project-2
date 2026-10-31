require "rails_helper"

RSpec.describe ConversationMessage do
  include CodeReviewHelpers

  before { seed_judge }

  let(:session) { create_attempt(create_user).practice_session }

  it "defaults to the coaching phase" do
    expect(session.conversation_messages.create!(role: "user", content: "hi").phase).to eq("coaching")
  end

  it "rejects an unknown phase" do
    expect(session.conversation_messages.new(role: "assistant", content: "x", phase: "gossip")).not_to be_valid
  end
end
