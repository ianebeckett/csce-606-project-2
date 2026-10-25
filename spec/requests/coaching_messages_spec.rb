require "rails_helper"

RSpec.describe "Coaching messages", type: :request do
  include CodeReviewHelpers

  before { seed_judge }
  after { use_ai_client(nil) }

  let(:premium) { create_user(email: "premium@example.com", role: "Premium") }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  def coaching_session(user) = user.practice_sessions.for_today(problem)

  def tell_coach(text)
    post problem_coaching_messages_path(problem), params: { conversation_message: { content: text } }
  end

  describe "when the AI service fails" do
    # A real request with a key OpenAI rejects, so the failure is genuine.
    before do
      use_ai_client(Ai::OpenAiClient.new(api_key: "sk-invalid-key-for-testing"))
      sign_in(premium)
      tell_coach("Return true if any number appears twice.")
    end

    it "keeps the candidate's message and saves no coach reply" do
      expect(coaching_session(premium).conversation_messages.pluck(:role, :content))
        .to eq([ [ "user", "Return true if any number appears twice." ] ])
    end

    it "unlocks the editor so the candidate can code" do
      expect(coaching_session(premium).coaching_state).to eq("skipped")
    end
  end

  describe "who can talk to the coach" do
    it "sends a logged-out visitor to sign in and saves nothing" do
      tell_coach("hello")

      expect(response).to redirect_to(new_session_path)
      expect(ConversationMessage.count).to eq(0)
    end

    it "denies a Free member and saves nothing" do
      sign_in(create_user(email: "free@example.com", role: "Free"))
      tell_coach("hello")

      expect(ConversationMessage.count).to eq(0)
    end

    it "never adds one member's message to another member's conversation" do
      other = create_user(email: "other@example.com", role: "Premium")
      sign_in(other)
      tell_coach("This is my message, not yours.")

      expect(coaching_session(premium).conversation_messages).to be_empty
      expect(coaching_session(other).conversation_messages.where(role: "user").count).to eq(1)
    end
  end

  describe "the code editor lock" do
    it "rejects code sent directly by a Premium member who has not finished coaching" do
      sign_in(premium)
      post problem_attempts_path(problem),
        params: { attempt: { code: RubySolutions::CORRECT.fetch("contains-duplicate"), language: "ruby" } }

      expect(Attempt.count).to eq(0)
    end

    it "shows a Free member the editor right away" do
      sign_in(create_user(email: "free@example.com", role: "Free"))
      get problem_path(problem)

      expect(response.body).to include("Ruby source code")
    end
  end
end
