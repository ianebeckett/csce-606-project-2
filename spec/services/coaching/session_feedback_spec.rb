
require "rails_helper"

RSpec.describe Coaching::SessionFeedback do
  before { seed_judge }

  let(:user) { create_user }
  let(:problem) { Problem.find_by!(slug: "contains-duplicate") }

  let(:practice_session) do
    user.practice_sessions.create!(
      problem: problem,
      started_at: Time.current,
      status: "completed",
      completed_at: Time.current
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
      "actionable_tips" => [ "Discuss time complexity more explicitly." ]
    }
  end

  it "generates structured feedback from the coaching conversation" do
    practice_session.conversation_messages.create!(
      role: "user",
      content: "I would use a hash set to track numbers."
    )

    practice_session.conversation_messages.create!(
      role: "assistant",
      content: "How would that help identify duplicates?"
    )

    client = double("AI client")

    expect(client).to receive(:complete)
                        .with(
                          hash_including(
                            system: kind_of(String),
                            prompt: a_string_including("hash set"),
                            schema: kind_of(Hash)
                          )
                        )
                        .and_return(feedback.to_json)

    result = described_class.new(client: client).call(practice_session)

    expect(result).to eq(feedback)
  end

  it "rejects feedback that is missing required fields" do
    practice_session.conversation_messages.create!(
    role: "user",
    content: "I would use a hash set to track duplicates."
   )

   client = double("AI client")
    allow(client).to receive(:complete).and_return(
    { "unexpected" => "value" }.to_json
   )

   # Feedback must follow the expected structure.
   expect {
    described_class.new(client: client).call(practice_session)
   }.to raise_error(Coaching::InvalidResponse)
  end


  it "rejects feedback for an incomplete session" do
    practice_session.update!(status: "in_progress")

    client = double("AI client")

    # The AI should never be called for an incomplete session.
    expect(client).not_to receive(:complete)

    expect {
      described_class.new(client: client).call(practice_session)
    }.to raise_error(Coaching::InvalidResponse, "Session is not completed.")
  end


  it "rejects feedback for an incomplete session" do
    practice_session.update!(status: "in_progress")

    client = double("AI client")

    # The AI should never be called for an incomplete session.
    expect(client).not_to receive(:complete)

    expect {
      described_class.new(client: client).call(practice_session)
    }.to raise_error(Coaching::InvalidResponse, "Session is not completed.")
  end
end
