require "rails_helper"

RSpec.describe Judge::Queue do
  before { seed_judge }

  it "locks PostgreSQL queue capacity before counting pending submissions" do
    connection = Attempt.connection
    expect(connection).to receive(:execute)
      .with("SELECT pg_advisory_xact_lock(1129268293, 1247102023)").ordered.and_call_original
    expect(Attempt).to receive(:where).with(judge_result: Attempt::PENDING).ordered.and_call_original
    attempt = create_user.practice_sessions.for_today(Problem.first).attempts.build(code: "saved source", total_cases: 6)

    expect(described_class.new.submit(attempt)).to be(true)
  end

  it "keeps retry advice positive when a running submission exceeds its estimate" do
    stub_const("Judge::Queue::MAX_PENDING", 1)
    session = create_user.practice_sessions.for_today(Problem.first)
    session.attempts.create!(code: "slow source", total_cases: 6, judging_started_at: 1.hour.ago)
    attempt = session.attempts.build(code: "retry source")

    expect { described_class.new.submit(attempt) }.to raise_error(Judge::Queue::Full) { |error|
      expect(error.retry_after).to eq(10)
    }
    expect(attempt).to be_new_record
  end

  it "does not let completed submissions consume capacity and validates before enqueueing" do
    stub_const("Judge::Queue::MAX_PENDING", 1)
    session = create_user.practice_sessions.for_today(Problem.first)
    session.attempts.create!(code: "completed source", judge_result: "Accepted")
    invalid = session.attempts.build(code: "puts 1", language: "python")

    expect(described_class.new.submit(invalid)).to be(false)
    expect(invalid.errors[:language]).not_to be_empty
    attempt = session.attempts.build(code: "saved source", total_cases: 6)
    expect(described_class.new.submit(attempt)).to be(true)
    expect(attempt.reload.judge_result).to eq("Pending")
  end
end
