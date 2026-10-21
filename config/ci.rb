CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Quality: Gate regression tests", "bundle exec rspec --options /dev/null .github/spec"
  step "Quality: Prepare test database", "env RAILS_ENV=test bin/rails db:prepare"
  step "Quality: Tests and coverage", "bin/quality"

  step "Style: Ruby", "bin/rubocop --fail-level info . bin/quality .github/scripts .github/spec"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
