require "rails_helper"

RSpec.describe "Turn-based interview", type: :request do
  include CodeReviewHelpers

  before { seed_judge }
  after { use_ai_client(nil) }

  let(:failure_alert) { "The interviewer is unavailable right now. Your message is saved, and the editor is unlocked." }
  let(:premium) { create_user(email: "premium@example.com", role: "Premium") }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  def interview_session(user) = user.practice_sessions.for_today(problem)

  def reply_with(message: "Good question.", advance: true)
    use_ai_client(Ai::FakeClient.new(reply: { message: message, advance: advance }.to_json))
  end

  def say(text, target: problem)
    post problem_interview_messages_path(target), params: { conversation_message: { content: text } }
  end

  describe "the interview page" do
    before { sign_in(premium) }

    it "shows a Premium member only the vague statement at first" do
      get problem_interview_path(problem)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(problem.interview_prompt))
      expect(response.body).not_to include(CGI.escapeHTML(problem.description))
      expect(response.body).not_to include("Ruby source code")
      expect(interview_session(premium).interview_state).to eq("clarifying")
    end

    it "shows what you've learned after clarification and the full problem only after the twist" do
      reply_with
      get problem_interview_path(problem)
      say("What are the inputs?")
      follow_redirect!

      expect(response.body).to include("What you've learned")
      expect(response.body).to include(CGI.escapeHTML(problem.interview_details.first["fact"]))
      expect(response.body).not_to include(CGI.escapeHTML(problem.description))

      say("A plan")
      follow_redirect!
      expect(response.body).to include(CGI.escapeHTML(problem.description))
    end

    it "posts the twist and unlocks after three accepted turns" do
      reply_with
      3.times { |i| say("turn #{i}") }
      follow_redirect!

      expect(interview_session(premium).interview_state).to eq("coding")
      expect(response.body).to include(CGI.escapeHTML(problem.interview_twist))
      expect(response.body).to include("Ruby source code")
      expect(interview_session(premium).coaching_state).to eq("complexity")
    end

    it "keeps the stage on advance false" do
      reply_with(advance: false)
      say("hmm")

      expect(interview_session(premium).interview_state).to eq("clarifying")
      expect(interview_session(premium).conversation_messages.interview.count).to eq(2)
    end

    it "lets a Premium member submit after the interview" do
      allow_any_instance_of(Judge::Submission).to receive(:call)
      reply_with
      3.times { |i| say("turn #{i}") }
      post problem_attempts_path(problem),
        params: { attempt: { code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby" } }

      expect(response).to redirect_to(attempt_path(Attempt.last))
    end

    it "keeps language selection inside the interview after unlocking the editor" do
      session = interview_session(premium)
      session.update!(interview_state: "coding", coaching_state: "complexity")

      get problem_interview_path(problem, language: "python")

      expect(response.body).to include("Python source code", "Python 3.15.2")
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('input[name="attempt[language]"]')["value"]).to eq("python")
      expect(document.at_css('a[aria-current="page"]')["href"])
        .to eq(problem_interview_path(problem, language: "python"))
    end

    it "on AI outage keeps the message, saves no reply, unlocks" do
      use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("x")))
      say("hello")

      expect(flash[:alert]).to eq(failure_alert)
      session = interview_session(premium)
      expect(session.interview_state).to eq("skipped")
      expect(session.coaching_state).to eq("complexity")
      expect(session.conversation_messages.pluck(:role, :content)).to eq([ [ "user", "hello" ] ])
    end

    it "lets the candidate submit after an AI outage" do
      allow_any_instance_of(Judge::Submission).to receive(:call)
      use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("x")))
      say("hello")
      post problem_attempts_path(problem),
        params: { attempt: { code: RubySolutions::CORRECT.fetch(problem.slug), language: "ruby" } }

      expect(response).to redirect_to(attempt_path(Attempt.last))
    end

    it "treats a non-JSON reply as an outage" do
      use_ai_client(Ai::FakeClient.new(reply: "not json"))
      say("hello")

      expect(flash[:alert]).to eq(failure_alert)
      expect(interview_session(premium).interview_state).to eq("skipped")
      expect(interview_session(premium).coaching_state).to eq("complexity")
      expect(interview_session(premium).conversation_messages.count).to eq(1)
    end

    it "rejects a blank message without calling the AI" do
      use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("must not be called")))
      say("   ")

      expect(response).to redirect_to(problem_interview_path(problem))
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).not_to eq(failure_alert)
      expect(interview_session(premium).conversation_messages.count).to eq(0)
      expect(interview_session(premium).interview_state).to eq("clarifying")
    end
  end

  describe "access" do
    it "redirects a Free member to the problem and saves nothing" do
      free = create_user(email: "free@example.com", role: "Free")
      sign_in(free)
      get problem_interview_path(problem)
      expect(response).to redirect_to(problem_path(problem))
      expect(flash[:alert]).to eq("The interviewer is a Premium feature.")

      say("hello")
      expect(response).to redirect_to(problem_path(problem))
      expect(ConversationMessage.count).to eq(0)
    end

    it "sends a signed-out visitor to sign in" do
      get problem_interview_path(problem)
      expect(response).to redirect_to(new_session_path)
      say("hello")
      expect(response).to redirect_to(new_session_path)
    end

    it "forbids a locked topic" do
      sign_in(premium)
      locked = Problem.find_by!(slug: "valid-palindrome")
      get problem_interview_path(locked)
      expect(response).to have_http_status(:forbidden)
      say("hello", target: locked)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for a problem without interview content" do
      sign_in(premium)
      problem.update_columns(interview_twist: nil)
      get problem_interview_path(problem)
      expect(response).to have_http_status(:not_found)
      say("hello")
      expect(response).to have_http_status(:not_found)
    end

    it "never shows or changes another member's interview" do
      reply_with
      sign_in(premium)
      say("my private question")
      other = create_user(email: "other@example.com", role: "Premium")
      post session_path, params: { email: other.email, password: "correct-horse-battery" }
      get problem_interview_path(problem)

      expect(response.body).not_to include("my private question")
      expect(interview_session(other).conversation_messages).to be_empty
      expect(interview_session(other).interview_state).to eq("clarifying")
    end
  end

  describe "isolation from the coach and history" do
    it "keeps interview text off the problem page and history" do
      reply_with(message: "Interviewer secret reply")
      sign_in(premium)
      say("Candidate secret question")

      get problem_path(problem)
      expect(response.body).not_to include("Candidate secret question")
      expect(response.body).not_to include("Interviewer secret reply")
      expect(response.body).to include("Practice as an interview")

      get history_index_path
      expect(response.body).not_to include("Candidate secret question")
    end
  end

  describe "the problem page entry" do
    it "hides the link from a Free member" do
      sign_in(create_user(email: "free@example.com", role: "Free"))
      get problem_path(problem)
      expect(response.body).not_to include("Practice as an interview")
    end
  end
end
