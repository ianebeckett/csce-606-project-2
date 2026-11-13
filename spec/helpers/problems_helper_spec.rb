require "rails_helper"

RSpec.describe ProblemsHelper, type: :helper do
  before { seed_judge }

  def first_input(slug)
    problem = Problem.find_by!(slug: slug)
    helper.example_input(problem, problem.test_cases.first)
  end

  it "shows a single array argument by name without an extra outer array" do
    expect(first_input("contains-duplicate")).to eq("nums = [1,2,3,1]")
  end

  it "names every argument when a problem takes several" do
    expect(first_input("binary-search")).to match(/\Anums = \[.*\], target = -?\d+\z/)
  end

  it "falls back to a numbered name when the starter code names fewer arguments" do
    problem = Problem.find_by!(slug: "contains-duplicate")
    test_case = TestCase.new(input: { "args" => [ [ 1 ], 2 ] })

    expect(helper.example_input(problem, test_case)).to eq("nums = [1], arg2 = 2")
  end
end
