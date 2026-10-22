module CoverageConfig
  MINIMUM_PERCENT = 90
  SOURCE_FILES = [ "app/**/*.rb", "judge/**/*.rb" ].freeze
  EXECUTOR_FILES = [ "/judge/main.rb", "/judge/runner.rb" ].freeze
  SUITE_REPORTS = %w[coverage/rspec/.resultset.json coverage/cucumber/.resultset.json].freeze
  TOTAL_REPORT_DIRECTORY = "coverage/total".freeze
end
