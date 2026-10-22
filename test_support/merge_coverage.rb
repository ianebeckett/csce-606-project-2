require "simplecov"
require_relative "coverage_config"

abort "Run both RSpec and Cucumber before merging coverage." unless CoverageConfig::SUITE_REPORTS.all? { |path| File.file?(path) }

SimpleCov.collate(CoverageConfig::SUITE_REPORTS) do
  cover(*CoverageConfig::SOURCE_FILES)
  coverage_dir CoverageConfig::TOTAL_REPORT_DIRECTORY
  minimum_coverage CoverageConfig::MINIMUM_PERCENT
end
