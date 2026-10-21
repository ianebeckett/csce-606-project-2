require "fileutils"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "Application coverage gates" do
  around do |example|
    Dir.mktmpdir("codecoach-coverage-") do |directory|
      @root = directory
      FileUtils.mkdir_p([ "#{directory}/test_support", "#{directory}/app" ])
      %w[coverage.rb coverage_config.rb merge_coverage.rb].each do |file|
        FileUtils.cp(File.expand_path("../../test_support/#{file}", __dir__), "#{directory}/test_support/#{file}")
      end
      10.times { |index| File.write("#{directory}/app/line#{index}.rb", "VALUE_#{index} = #{index}\n") }
      @environment = {
        "BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__),
        "COVERAGE_ROOT" => "#{directory}/reports",
        "COVERAGE" => "1"
      }
      example.run
    end
  end

  def run_suite(suite, files)
    source = "require './test_support/coverage'; " +
      files.map { |index| "require './app/line#{index}'" }.join("; ")
    name = { "rspec" => "RSpec", "cucumber" => "Cucumber" }.fetch(suite)
    Open3.capture3(@environment.merge("COVERAGE_SUITE" => name), "bundle", "exec", "ruby", "-e", source, chdir: @root)
  end

  def combine
    Open3.capture3(@environment, "bundle", "exec", "ruby", "test_support/merge_coverage.rb", chdir: @root)
  end

  it "passes exactly 90 percent and counts unloaded files" do
    output, error, status = run_suite("rspec", 0...9)
    expect(status.success?).to be(true), output + error
    result = JSON.parse(File.read("#{@root}/reports/rspec/.last_run.json"))
    expect(result.fetch("result").fetch("line")).to eq(90.0)
  end

  it "fails below 90 percent" do
    _output, _error, status = run_suite("rspec", 0...8)
    expect(status.success?).to be(false)
  end

  it "does not let acceptance coverage mask a failing unit threshold" do
    expect(run_suite("rspec", 0...8).last.success?).to be(false)
    expect(run_suite("cucumber", 0...10).last.success?).to be(true)
    expect(combine.last.success?).to be(true)
  end

  it "merges executed lines instead of averaging suite percentages" do
    expect(run_suite("rspec", 0...9).last.success?).to be(true)
    expect(run_suite("cucumber", 1...10).last.success?).to be(true)
    output, error, status = combine
    expect(status.success?).to be(true), output + error
    result = JSON.parse(File.read("#{@root}/reports/total/.last_run.json"))
    expect(result.fetch("result").fetch("line")).to eq(100.0)
  end

  it "fails combined coverage below 90 percent" do
    run_suite("rspec", 0...8)
    run_suite("cucumber", 0...8)
    expect(combine.last.success?).to be(false)
  end

  it "rejects a missing suite result" do
    run_suite("rspec", 0...10)
    output, error, status = combine
    expect(status.success?).to be(false)
    expect(output + error).to include("Run both RSpec and Cucumber")
  end

  it "does not reuse a previous run's hits for the same suite" do
    expect(run_suite("rspec", 0...10).last.success?).to be(true)
    expect(run_suite("rspec", 0...8).last.success?).to be(false)
  end
end
