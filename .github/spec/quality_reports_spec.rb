require "json"
require "tmpdir"
require_relative "../scripts/quality_reports"

RSpec.describe QualityReports do
  around do |example|
    Dir.mktmpdir("codecoach-reports-") do |directory|
      @report = File.join(directory, "report.json")
      example.run
    end
  end

  def write_report(data)
    File.write(@report, JSON.generate(data))
    @report
  end

  def rspec_report(examples: 1, failures: 0, pending: 0)
    { summary: { example_count: examples, failure_count: failures, pending_count: pending } }
  end

  def cucumber_report(status: "passed", steps: 3)
    [ { elements: [ { type: "scenario", steps: Array.new(steps) { { result: { status: status } } } } ] } ]
  end

  it "accepts a nonempty passing RSpec run" do
    expect(described_class.rspec(write_report(rspec_report))).to eq(1)
  end

  it "rejects an empty RSpec suite" do
    expect { described_class.rspec(write_report(rspec_report(examples: 0))) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects failed RSpec examples" do
    expect { described_class.rspec(write_report(rspec_report(failures: 1))) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects pending RSpec examples" do
    expect { described_class.rspec(write_report(rspec_report(pending: 1))) }.to raise_error(QualityReports::Invalid)
  end

  it "accepts executed Cucumber scenarios" do
    expect(described_class.cucumber(write_report(cucumber_report))).to eq(1)
  end

  it "does not count a background as a scenario" do
    report = cucumber_report
    report.first[:elements].first[:type] = "background"
    expect { described_class.cucumber(write_report(report)) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects an empty Cucumber suite" do
    expect { described_class.cucumber(write_report([])) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects scenarios with no steps" do
    expect { described_class.cucumber(write_report(cucumber_report(steps: 0))) }.to raise_error(QualityReports::Invalid)
  end

  %w[failed pending undefined skipped ambiguous].each do |status|
    it "rejects #{status} Cucumber steps" do
      expect { described_class.cucumber(write_report(cucumber_report(status: status))) }.to raise_error(QualityReports::Invalid)
    end
  end

  it "rejects missing reports" do
    expect { described_class.rspec(@report) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects malformed JSON" do
    File.write(@report, "{")
    expect { described_class.cucumber(@report) }.to raise_error(QualityReports::Invalid)
  end

  it "rejects an incomplete RSpec summary" do
    expect { described_class.rspec(write_report({ summary: {} })) }.to raise_error(QualityReports::Invalid)
  end
end
