require_relative "coverage_config"

if ENV["COVERAGE"] == "0"
  abort "CI must run with coverage enabled." if ENV["CI"]
else
  require "simplecov"
  ENV["JUDGE_COVERAGE"] = "1"

  SimpleCov.start do
    command_name ENV.fetch("COVERAGE_SUITE")
    coverage_dir "coverage/#{ENV.fetch('COVERAGE_SUITE').downcase}"
    cover(*CoverageConfig::SOURCE_FILES)
    merging false
    minimum_coverage CoverageConfig::MINIMUM_PERCENT
  end

  module DockerCoverage
    class << self
      def record(coverage)
        return unless coverage

        mapped = coverage.each_with_object({}) do |(path, data), output|
          next unless CoverageConfig::EXECUTOR_FILES.include?(path)

          local = File.expand_path("../judge/#{File.basename(path)}", __dir__)
          output[local] = { "lines" => data.fetch("lines") }
        end
        @measured = SimpleCov::Combine::ResultsCombiner.combine(@measured || {}, mapped)
      end

      def measured
        @measured || {}
      end
    end

    module Runner
      def call(**arguments)
        result = super
        DockerCoverage.record(result.delete("coverage"))
        result
      end
    end
  end

  SimpleCov.at_exit do
    own = SimpleCov.result
    merged = SimpleCov::Combine::ResultsCombiner.combine(own.original_result, DockerCoverage.measured)
    result = SimpleCov::Result.new(merged, command_name: own.command_name, tracked_files: own.tracked_files)
    SimpleCov.current_run.result = result
    SimpleCov::ResultMerger.store_result(result)
    result.format!
  end
end
