require "rails_helper"

RSpec.describe "AI code review requests", type: :request do
  include CodeReviewHelpers

  before { seed_judge }
  after { use_ai_client(nil) }

  let(:premium) { create_user(email: "premium@example.com", role: "Premium") }
  let(:attempt) { create_attempt(premium) }
  let(:hash_set_tip) { { category: "complexity", line_start: 2, line_end: 2, message: "Use a Set to make this O(n)." } }

  describe "a Premium member" do
    before { sign_in(premium) }

    it "sees the review with each suggestion under the line it refers to" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ hash_set_tip ])))

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body).to include("Correct, but the nested scan is quadratic.")
      expect(body).to include("O(n^2)")
      line_two = body.index("nums.each_with_index")
      expect(body.index("Use a Set to make this O(n).")).to be > line_two
      expect(body.index("Use a Set to make this O(n).")).to be < body.index("<code>end</code>")
    end

    it "labels a suggestion that spans several lines with its range" do
      span = { category: "correctness", line_start: 1, line_end: 3, message: "Return early when nums is empty." }
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ span ])))

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(response.body).to include("Lines 1–3")
    end

    it "lists suggestions without a line separately" do
      general = { category: "anti_pattern", message: "Name the block variables clearly." }
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ general ])))

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(response.body).to include("General suggestions")
      expect(response.body).to include("Name the block variables clearly.")
      expect(response.body).to include("Anti-pattern")
    end

    it "sends the problem and judge result to the AI" do
      client = Ai::FakeClient.new(reply: ai_review_reply)
      use_ai_client(client)

      post attempt_code_review_path(attempt)

      expect(client.last_prompt).to include(attempt.problem.description)
      expect(client.last_prompt).to include("Accepted (6/6 test cases passed)")
    end

    it "escapes HTML in the AI's reply" do
      tip = hash_set_tip.merge(message: "<script>alert(1)</script>")
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ tip ])))

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(response.body).not_to include("<script>alert(1)</script>")
      expect(response.body).to include("&lt;script&gt;")
    end

    it "saves the review as a code review message on the attempt" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ hash_set_tip ])))

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_code_review_path(attempt))
      saved = ConversationMessage.sole
      expect(saved).to have_attributes(practice_session: attempt.practice_session, attempt: attempt, role: "assistant", phase: "code_review")
      expect(JSON.parse(saved.content)).to include("summary" => "Correct, but the nested scan is quadratic.")
    end

    it "shows a saved review again without calling the AI" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply(suggestions: [ hash_set_tip ])))
      post attempt_code_review_path(attempt)
      second = Ai::FakeClient.new(reply: ai_review_reply)
      use_ai_client(second)

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(second.last_prompt).to be_nil
      expect(response.body).to include("Use a Set to make this O(n).")
      expect(ConversationMessage.count).to eq(1)
    end

    it "links to the saved review from the attempt page" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply))
      post attempt_code_review_path(attempt)

      get attempt_path(attempt)

      expect(response.body).to include("View AI code review")
      expect(response.body).not_to include("Get AI code review")
    end

    it "sends a visit to an unreviewed attempt back to the attempt page" do
      get attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
    end

    it "saves nothing when the AI fails" do
      use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("timeout")))

      post attempt_code_review_path(attempt)

      expect(ConversationMessage.count).to eq(0)
    end

    it "keeps saved reviews out of the Socratic coach's prompt and chat" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply))
      post attempt_code_review_path(attempt)
      coach = Ai::FakeClient.new(reply: { message: "What is the input size?", advance: false }.to_json)
      use_ai_client(coach)

      post problem_coaching_messages_path(attempt.problem), params: { conversation_message: { content: "I would use a hash set." } }
      get problem_path(attempt.problem)

      expect(coach.last_prompt).to include("I would use a hash set.")
      expect(coach.last_prompt).not_to include("nested scan is quadratic")
      expect(response.body).not_to include("nested scan is quadratic")
    end

    it "keeps the attempt and explains when the AI service fails" do
      use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("timeout")))

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      follow_redirect!
      expect(response.body).to include("AI code review is unavailable right now")
      expect(response.body).to include("nums.each_with_index")
    end

    it "explains when the AI reply can't be used" do
      use_ai_client(Ai::FakeClient.new(reply: "Sorry, I can't help with that."))

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      expect(flash[:alert]).to include("AI code review is unavailable right now")
    end

    it "explains instead of erroring when the AI reply is not valid UTF-8" do
      use_ai_client(Ai::FakeClient.new(reply: "{\"summary\": \"\xFF\"}".dup.force_encoding("UTF-8")))

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      expect(flash[:alert]).to include("AI code review is unavailable right now")
    end

    it "explains instead of erroring when the AI reply is binary with invalid bytes" do
      use_ai_client(Ai::FakeClient.new(reply: "{\"summary\": \"\xFF\"}".b))

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      expect(flash[:alert]).to include("AI code review is unavailable right now")
    end

    it "shows the review when the AI reply is encoded as UTF-16" do
      use_ai_client(Ai::FakeClient.new(reply: ai_review_reply.encode("UTF-16LE")))

      post attempt_code_review_path(attempt)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Correct, but the nested scan is quadratic.")
    end

    it "explains when no AI provider is configured" do
      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      expect(flash[:alert]).to include("AI code review is unavailable right now")
    end

    it "offers the review button on the attempt page" do
      get attempt_path(attempt)

      expect(response.body).to include("Get AI code review")
    end

    it "does not offer a review for a blank submission" do
      attempt.update_column(:code, " \n")

      get attempt_path(attempt)

      expect(response.body).not_to include("Get AI code review")
    end

    it "does not contact the AI for a blank submission" do
      attempt.update_column(:code, "")
      client = Ai::FakeClient.new(reply: ai_review_reply)
      use_ai_client(client)

      post attempt_code_review_path(attempt)

      expect(response).to redirect_to(attempt_path(attempt))
      expect(flash[:alert]).to eq("There's no code to review yet.")
      expect(client.last_prompt).to be_nil
    end

    it "cannot view another member's saved review" do
      other = create_attempt(create_user(email: "other@example.com", role: "Premium"))

      get attempt_code_review_path(other)

      expect(response).to have_http_status(:not_found)
    end

    it "cannot review another member's attempt" do
      other = create_attempt(create_user(email: "other@example.com", role: "Premium"))
      client = Ai::FakeClient.new(reply: ai_review_reply)
      use_ai_client(client)

      post attempt_code_review_path(other)

      expect(response).to have_http_status(:not_found)
      expect(client.last_prompt).to be_nil
    end
  end

  describe "a Free member" do
    let(:free) { create_user(email: "free@example.com", role: "Free") }
    let(:free_attempt) { create_attempt(free) }

    before { sign_in(free) }

    it "is told the review is a Premium feature and the AI is never called" do
      client = Ai::FakeClient.new(reply: ai_review_reply)
      use_ai_client(client)

      post attempt_code_review_path(free_attempt)

      expect(response).to redirect_to(attempt_path(free_attempt))
      expect(flash[:alert]).to eq("AI code review is a Premium feature.")
      expect(client.last_prompt).to be_nil
    end

    it "sees an explanation instead of the review button" do
      get attempt_path(free_attempt)

      expect(response.body).not_to include("Get AI code review")
      expect(response.body).to include("AI code review is available to Premium members.")
    end
  end

  it "requires signing in" do
    post attempt_code_review_path(attempt)

    expect(response).to redirect_to(new_session_path)
  end
end
