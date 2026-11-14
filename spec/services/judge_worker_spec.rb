require "rails_helper"

RSpec.describe Judge::Worker do
  it "only configures a bounded pool when Heroku credentials are present" do
    previous = ENV.to_h.slice("JUDGE_HEROKU_APP", "JUDGE_HEROKU_TOKEN", "JUDGE_READY_POOL_SIZE")
    ENV.delete("JUDGE_HEROKU_APP")
    expect(described_class.configured_pool).to be_nil
    ENV["JUDGE_HEROKU_APP"] = "codecoach"
    ENV["JUDGE_HEROKU_TOKEN"] = "test-secret"
    ENV["JUDGE_READY_POOL_SIZE"] = "0"
    expect(described_class.configured_pool).to be_nil
    ENV["JUDGE_READY_POOL_SIZE"] = "2"
    expect(described_class.configured_pool).to be_a(Judge::HerokuPool)
    ENV["JUDGE_READY_POOL_SIZE"] = "3"
    expect { described_class.configured_pool }.to raise_error(ArgumentError)
  ensure
    %w[JUDGE_HEROKU_APP JUDGE_HEROKU_TOKEN JUDGE_READY_POOL_SIZE].each { |key| ENV[key] = previous[key] }
  end

  it "starts the pool before the worker and always releases it on shutdown" do
    pool = instance_double(Judge::HerokuPool)
    worker = instance_double(Delayed::Worker)
    expect(pool).to receive(:start).ordered
    expect(worker).to receive(:start).ordered do
      expect(Judge::HerokuDynoRunner.pool).to eq(pool)
      raise IOError, "worker stopped"
    end
    expect(pool).to receive(:stop).ordered

    expect { described_class.run(worker: worker, pool: pool) }.to raise_error(IOError)
    expect(Judge::HerokuDynoRunner.pool).to be_nil
    expect(Delayed::Worker.sleep_delay).to eq(1)
  end

  it "can run without a pool for local judging" do
    worker = instance_double(Delayed::Worker)
    expect(worker).to receive(:start)
    described_class.run(worker: worker, pool: nil)
    expect(Judge::HerokuDynoRunner.pool).to be_nil
  end
end
