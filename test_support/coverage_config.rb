module CoverageConfig
  MINIMUM_PERCENT = 90
  SOURCE_FILES = [ "app/**/*.rb", "lib/**/*.rb", "judge/**/*.rb" ].freeze
  EXECUTOR_FILES = [ "/judge/main.rb", "/judge/runner.rb" ].freeze
  REPORT_ROOT = ENV.fetch("COVERAGE_ROOT", "coverage").freeze
  SUITE_REPORTS = %w[rspec cucumber].map { |suite| File.join(REPORT_ROOT, suite, ".resultset.json") }.freeze
  TOTAL_REPORT_DIRECTORY = File.join(REPORT_ROOT, "total").freeze
end
