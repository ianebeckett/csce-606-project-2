ENV["RAILS_ENV"] = "test"
ENV["COVERAGE_SUITE"] = "RSpec"
require_relative "../test_support/coverage"
require_relative "../config/environment"
require "rspec/rails"
require_relative "support/judge_helpers"
require_relative "fixtures/ruby_solutions"
require_relative "fixtures/language_solutions"
require_relative "support/code_review_helpers"

ActiveRecord::Migration.maintain_test_schema!
Rails.application.eager_load!
ActiveModel::SecurePassword.min_cost = true
Judge::DockerRunner.prepend(DockerCoverage::Runner) if defined?(DockerCoverage)

RSpec.configure do |config|
  config.fail_if_no_examples = true
  # FAST=1 (bin/test-fast) skips examples tagged :docker (they start real
  # containers) or :slow (real waits or network calls). CI runs everything.
  config.filter_run_excluding docker: true, slow: true if ENV["FAST"]
  # Seed the problems once per run. Each example runs in a transaction that
  # is rolled back, so seed_judge inside an example only has to confirm the
  # rows exist, which is several times faster than inserting them.
  config.before(:suite) { load Rails.root.join("db/seeds.rb") }
  config.after(:suite) do
    [ ReviewSchedule, ConversationMessage, Attempt, PracticeSession, TestCase, TopicPrerequisite, Problem, Topic ].each(&:delete_all)
  end
  config.use_transactional_fixtures = true
  config.include JudgeHelpers
  config.order = :random
  Kernel.srand config.seed
end
