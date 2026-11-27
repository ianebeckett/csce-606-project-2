
require "rails_helper"

RSpec.describe "Session Feedback", type: :request do
  include CodeReviewHelpers

  before { seed_judge }
  after { use_ai_client(nil) }

  let(:user) { create_user(email: "feedback@example.com", role: "Premium") }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  let(:practice_session) do
    user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current
    )
  end

  let(:attempt) do
    practice_session.attempts.create!(
      code: "def contains_duplicate(nums); false; end",
      language: "ruby",
      judge_result: Attempt::ACCEPTED
    )
  end

  let(:feedback) do
    {
      "summary" => "Good understanding of the problem.",
      "conceptual_accuracy" => {
        "assessment" => "The approach was correct.",
        "strengths" => [ "Recognized the need to track duplicates." ],
        "weaknesses" => []
      },
      "explanation_quality" => {
        "assessment" => "The explanation was clear.",
        "strengths" => [ "Explained the approach clearly." ],
        "weaknesses" => []
      },
      "actionable_tips" => [ "Explain time complexity more clearly." ]
    }
  end

  it "generates and saves feedback when a session is completed" do
    practice_session.conversation_messages.create!(
      role: "user",
      content: "I would use a hash set to track duplicates."
    )

    practice_session.conversation_messages.create!(
      role: "assistant",
      content: "How would that help identify duplicates?"
    )

    # Provide a predictable AI response for the request test.
    use_ai_client(Ai::FakeClient.new(reply: feedback.to_json))

    sign_in(user)

    patch rate_practice_session_path(practice_session), params: {
      review_rating: 4,
      attempt_id: attempt.id
    }

    expect(response).to redirect_to(attempt_path(attempt))
    expect(practice_session.reload.status).to eq("completed")
    expect(practice_session.feedback_summary).to eq(feedback.to_json)
  end

  it "completes the session even when AI feedback generation fails" do
    practice_session.conversation_messages.create!(
      role: "user",
      content: "I would use a hash set to track duplicates."
    )

    practice_session.conversation_messages.create!(
      role: "assistant",
      content: "How would that help identify duplicates?"
    )

    # Simulate an AI service failure.
    use_ai_client(Ai::FakeClient.new(error: Ai::Error.new("AI unavailable")))

    sign_in(user)

    patch rate_practice_session_path(practice_session), params: {
      review_rating: 4,
      attempt_id: attempt.id
    }

    expect(response).to redirect_to(attempt_path(attempt))
    expect(practice_session.reload.status).to eq("completed")
    expect(practice_session.review_scheduled_at).to be_present
    expect(practice_session.feedback_summary).to be_blank
  end
end
