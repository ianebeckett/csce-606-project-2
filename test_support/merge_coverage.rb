require "simplecov"
require "json"
require_relative "coverage_config"

abort "Run both RSpec and Cucumber before merging coverage." unless CoverageConfig::SUITE_REPORTS.all? { |path| File.file?(path) }

CoverageConfig::SUITE_REPORTS.zip(%w[RSpec Cucumber]).each do |path, suite|
  abort "Missing #{suite} result in #{path}" unless JSON.parse(File.read(path)).key?(suite)
end

SimpleCov.collate(CoverageConfig::SUITE_REPORTS) do
  root File.expand_path("..", __dir__)
  cover(*CoverageConfig::SOURCE_FILES)
  coverage_dir CoverageConfig::TOTAL_REPORT_DIRECTORY
  minimum_coverage CoverageConfig::MINIMUM_PERCENT
end
