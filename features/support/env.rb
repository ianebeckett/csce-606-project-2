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

ActiveRecord::Migration.maintain_test_schema!
Rails.application.eager_load!
ActiveModel::SecurePassword.min_cost = true
Judge::DockerRunner.prepend(DockerCoverage::Runner) if defined?(DockerCoverage)
Capybara.app = Rails.application
Capybara.default_driver = :rack_test
DatabaseCleaner.strategy = :transaction
World(JudgeHelpers, RSpec::Matchers, ActiveJob::TestHelper, ActiveSupport::Testing::TimeHelpers)

After do
  clear_enqueued_jobs
  clear_performed_jobs
  travel_back
end
