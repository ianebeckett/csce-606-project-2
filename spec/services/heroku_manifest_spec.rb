require "rails_helper"
require "yaml"

RSpec.describe "Heroku judge deployment" do
  let(:manifest) { YAML.load_file(Rails.root.join("heroku.yml")) }

  it "builds the isolated judge image in the same release as the queue" do
    builds = manifest.fetch("build").fetch("docker")
    expect(builds.fetch("queue")).to eq("dockerfile" => "Dockerfile", "target" => "heroku-queue")
    expect(builds.fetch(Judge::HerokuDynoRunner::PROCESS_TYPE)).to eq("judge/Dockerfile")
    expect(manifest.fetch("release")).to eq(
      "image" => "release", "command" => [ "./bin/rails db:migrate db:seed" ])
  end

  it "boots the ready pool through the queue image's deployed command" do
    # A run override previously bypassed the pool even though the image CMD
    # was correct. Keep the manifest and actual executable in this regression.
    expect(manifest).not_to have_key("run")
    dockerfile = Rails.root.join("Dockerfile").read
    queue_stage = dockerfile.split("FROM app AS heroku-queue\n").fetch(1).split(/^FROM /).first
    command = JSON.parse(queue_stage.match(/^CMD (.+)$/)[1])
    expect(command.first(3)).to eq(%w[bundle exec ruby])

    pool = instance_double(Judge::HerokuPool)
    worker = instance_double(Delayed::Worker)
    allow(Judge::Worker).to receive(:configured_pool).and_return(pool)
    allow(Delayed::Worker).to receive(:new).with(queues: [ "judge" ]).and_return(worker)
    expect(pool).to receive(:start).ordered
    expect(worker).to receive(:start).ordered do
      expect(Judge::HerokuDynoRunner.pool).to eq(pool)
    end
    expect(pool).to receive(:stop).ordered

    load Rails.root.join(command.fetch(3))

    expect(Judge::HerokuDynoRunner.pool).to be_nil
  end
end
