ENV["RAILS_ENV"] = "test"
ENV["COVERAGE_SUITE"] = "Cucumber"
require_relative "../../test_support/coverage"
require_relative "../../config/environment"
require "cucumber/rails"
require "rspec/expectations"
require "database_cleaner/active_record"
require "active_support/testing/time_helpers"
require "active_job/test_helper"
require_relative "../../spec/support/judge_helpers"
require_relative "../../spec/fixtures/ruby_solutions"
require_relative "../../spec/fixtures/language_solutions"
require_relative "../../spec/support/code_review_helpers"

ActiveRecord::Migration.maintain_test_schema!
Rails.application.eager_load!
ActiveModel::SecurePassword.min_cost = true
Judge::DockerRunner.prepend(DockerCoverage::Runner) if defined?(DockerCoverage)
Capybara.app = Rails.application
Capybara.default_driver = :rack_test
DatabaseCleaner.strategy = :transaction
World(JudgeHelpers, CodeReviewHelpers, RSpec::Matchers, ActiveJob::TestHelper, ActiveSupport::Testing::TimeHelpers)

After do
  clear_enqueued_jobs
  clear_performed_jobs
  travel_back
  if @remote_judge_configured
    ENV["JUDGE_URL"] = @previous_judge_url
    ENV["JUDGE_TOKEN"] = @previous_judge_token
  end
  Judge::Runner.define_singleton_method(:build, @original_judge_runner_build) if @original_judge_runner_build
end

# Seed the problems once per run. Scenarios run in transactions that are
# rolled back, so the seed step only has to confirm the rows exist.
BeforeAll { load Rails.root.join("db/seeds.rb") }
AfterAll do
  [ ReviewSchedule, ConversationMessage, Attempt, PracticeSession, TestCase, TopicPrerequisite, Problem, Topic ].each(&:delete_all)
end
