ENV["RAILS_ENV"] = "test"
ENV["COVERAGE_SUITE"] = "RSpec"
require_relative "../test_support/coverage"
require_relative "../config/environment"
require "rspec/rails"
require_relative "support/judge_helpers"
require_relative "fixtures/ruby_solutions"
require_relative "support/code_review_helpers"

ActiveRecord::Migration.maintain_test_schema!
Rails.application.eager_load!
ActiveModel::SecurePassword.min_cost = true
Judge::DockerRunner.prepend(DockerCoverage::Runner) if defined?(DockerCoverage)

RSpec.configure do |config|
  config.fail_if_no_examples = true
  config.use_transactional_fixtures = true
  config.include JudgeHelpers
  config.order = :random
  Kernel.srand config.seed
end
