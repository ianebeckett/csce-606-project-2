require "rails_helper"

# Opt in with JUDGE_INTEGRATION=1. These compile real programs in fresh containers.
RSpec.describe Judge::DockerRunner, :integration, :docker do
  %w[python go cpp].each do |language|
    context "with #{language}" do
      %w[contains-duplicate reverse-linked-list].each do |slug|
        it "executes #{slug} against every predefined case" do
          problem = Problem.find_by!(slug: slug)
          cases = problem.test_cases.order(:position)
          result = described_class.new.call(
            code: LanguageSolutions::CORRECT.fetch(language).fetch(slug), language: language,
            problem: problem, inputs: cases.map(&:input))

          expect(result.fetch("status")).to eq("ok")
          expect(result.fetch("outputs")).to eq(cases.map(&:expected_output))
          expect(result.fetch("runtime")).to eq(Attempt.language_version(language))
        end
      end

      it "reports a real runtime failure" do
        problem = Problem.find_by!(slug: "contains-duplicate")
        result = described_class.new.call(
          code: LanguageSolutions::RUNTIME_ERROR.fetch(language), language: language,
          problem: problem, inputs: [ problem.test_cases.first.input ])

        expect(result.fetch("status")).to eq("Runtime Error")
        expect(result.fetch("outputs")).to be_empty
      end

      it "reports a real compilation error" do
        problem = Problem.find_by!(slug: "contains-duplicate")
        result = described_class.new.call(
          code: LanguageSolutions::INVALID.fetch(language), language: language,
          problem: problem, inputs: [ problem.test_cases.first.input ])

        expect(result.fetch("status")).to eq("Compilation Error")
        expect(result.fetch("outputs")).to be_empty
      end

      it "terminates a real infinite loop with a timeout" do
        problem = Problem.find_by!(slug: "contains-duplicate")
        result = described_class.new.call(
          code: LanguageSolutions::TIMEOUT.fetch(language), language: language,
          problem: problem, inputs: [ problem.test_cases.first.input ])

        expect(result.fetch("status")).to eq("Timeout")
        expect(result.fetch("outputs")).to be_empty
      end
    end
  end
end
