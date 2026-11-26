require "rails_helper"

RSpec.describe Judge::HerokuPool do
  class PoolTestSession
    attr_accessor :alive
    attr_reader :closed

    def initialize
      @alive = true
      @closed = false
    end

    def usable? = @alive && !@closed
    def close = @closed = true
  end

  def await_pool
    Timeout.timeout(2) { sleep 0.005 until yield }
  end

  after { @pool&.stop }

  it "keeps two unused sessions and replaces each claimed session without reusing it" do
    created = Queue.new
    @pool = described_class.new(size: 2, factory: -> { PoolTestSession.new.tap { |session| created << session } })
    @pool.start
    await_pool { @pool.ready_count == 2 }

    first = @pool.checkout(timeout: 1)
    second = @pool.checkout(timeout: 1)
    expect(first).not_to equal(second)
    await_pool { created.size == 4 && @pool.ready_count == 2 }
    @pool.stop
    expect(first.closed).to be(false)
    expect(second.closed).to be(false)
    4.times.map { created.pop }.reject { |session| [ first, second ].include?(session) }.each do |session|
      expect(session.closed).to be(true)
    end
  ensure
    first&.close
    second&.close
  end

  it "retires idle and disconnected sessions before handing out replacements" do
    created = Queue.new
    @pool = described_class.new(size: 1, idle_timeout: 0.05,
      factory: -> { PoolTestSession.new.tap { |session| created << session } })
    @pool.start
    first = created.pop
    await_pool { first.closed }
    second = created.pop
    second.alive = false
    third = @pool.checkout(timeout: 1)
    expect(third).not_to equal(first)
    expect(third).not_to equal(second)
    expect(second.closed).to be(true)
  ensure
    third&.close
  end

  it "backs off after startup failures and bounds the wait when no session is ready" do
    @pool = described_class.new(size: 1, retry_delay: 0.02, factory: -> { raise IOError, "secret endpoint" })
    expect(Rails.logger).to receive(:warn).with("Judge ready pool: IOError").at_least(:once)
    @pool.start
    expect { @pool.checkout(timeout: 0.04) }.to raise_error(Timeout::Error)
    @pool.stop
    expect { @pool.checkout(timeout: 0.01) }.to raise_error(IOError)
  end

  it "closes a session that finishes warming during shutdown" do
    entered = Queue.new
    release = Queue.new
    session = PoolTestSession.new
    @pool = described_class.new(size: 1, factory: -> { entered << true; release.pop; session })
    @pool.start
    entered.pop
    stopper = Thread.new { @pool.stop }
    await_pool { !@pool.running? }
    release << true
    stopper.join
    expect(session.closed).to be(true)
  end
end
