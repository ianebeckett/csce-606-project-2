require "json"

module QualityReports
  class Invalid < StandardError; end

  def self.read(path)
    JSON.parse(File.read(path))
  rescue Errno::ENOENT, JSON::ParserError => error
    raise Invalid, "Missing or invalid report #{path}: #{error.message}"
  end

  def self.rspec(path)
    summary = read(path).fetch("summary")
    count = summary.fetch("example_count")
    unless count.positive? && summary.fetch("failure_count").zero? && summary.fetch("pending_count").zero?
      raise Invalid, "RSpec must execute examples with no failures or pending examples"
    end
    count
  rescue KeyError, NoMethodError, TypeError => error
    raise Invalid, "Invalid RSpec summary: #{error.message}"
  end

  def self.cucumber(path)
    scenarios = read(path).flat_map { |feature| feature.fetch("elements", []) }
      .select { |element| element.fetch("type") == "scenario" }
    if scenarios.empty? || scenarios.any? { |scenario| !passed_scenario?(scenario) }
      raise Invalid, "Cucumber must execute scenarios with nonempty, passing steps"
    end
    scenarios.length
  rescue KeyError, NoMethodError, TypeError => error
    raise Invalid, "Invalid Cucumber report: #{error.message}"
  end

  def self.passed_scenario?(scenario)
    steps = scenario.fetch("steps")
    !steps.empty? && steps.all? { |step| step.dig("result", "status") == "passed" }
  end
end
