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

  describe "stage progress" do
    before { sign_in(premium) }

    it "remembers the stage just passed for the next page only" do
      use_ai_client(Ai::FakeClient.new(reply: { message: "Right.", advance: true }.to_json))

      tell_coach("Return true if any number repeats.")
      expect(flash[:coaching_stage_passed]).to eq("problem")

      follow_redirect!
      expect(response.body).to include("coach-step stage-shine", ">Step 2 of 3")
      expect(response.body).not_to include("data-testid=\"editor-unlocked\"")

      get problem_path(problem)
      expect(response.body).not_to include("stage-shine")
    end

    it "announces the editor unlock after the approach is accepted" do
      coaching_session(premium).update!(coaching_state: "approach")
      use_ai_client(Ai::FakeClient.new(reply: { message: "Correct.", advance: true }.to_json))

      tell_coach("Use a hash set.")
      follow_redirect!

      expect(response.body).to include("coach-step stage-shine", "data-testid=\"editor-unlocked\"", "editor-just-unlocked")
    end

    it "does not flag a stage when the final stage cannot advance" do
      coaching_session(premium).update!(coaching_state: "complexity")
      use_ai_client(Ai::FakeClient.new(reply: { message: "O(n).", advance: true }.to_json))

      tell_coach("It is O(n) time.")

      expect(flash[:coaching_stage_passed]).to be_nil
    end

    it "keeps the stage-passed key out of the page banners" do
      use_ai_client(Ai::FakeClient.new(reply: { message: "Right.", advance: true }.to_json))

      tell_coach("Return true if any number repeats.")
      follow_redirect!

      expect(response.body).not_to include("notice coaching_stage_passed")
    end
  end

  describe "chat page" do
    before { sign_in(premium) }

    it "marks the chat log as scrollable and the form as a chat form" do
      get problem_path(problem)

      expect(response.body).to include("data-chat-log", "data-chat-form", "Senior SWE is thinking")
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

  describe "the problem page" do
    it "tells a Free member to upgrade for Socratic code coaching" do
      sign_in(create_user(email: "free@example.com", role: "Free"))
      get problem_path(problem)

      expect(response.body).to include("Upgrade to Premium to use Socratic code coaching")
      expect(response.body).not_to include("Your message")
    end

    it "offers a Premium member the Ctrl + Enter send shortcut" do
      sign_in(premium)
      get problem_path(problem)

      expect(response.body).to include("Send (Ctrl + Enter)", "data-submit-on-ctrl-enter", 'type="importmap"')
      expect(response.body).not_to include("Upgrade to Premium")
    end
  end
end
