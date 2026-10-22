CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Tests: RSpec", "COVERAGE=1 bundle exec rspec"
  step "Tests: Cucumber", "COVERAGE=1 bundle exec cucumber"
  step "Tests: Total coverage", "bundle exec ruby test_support/merge_coverage.rb"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
