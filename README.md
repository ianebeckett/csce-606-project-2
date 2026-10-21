# Code Coach

## Install

- Git
- Ruby 4.0.1
- Bundler 4.0.19
- GNU Make
- Docker Desktop (macOS or Windows) or Docker Engine (Linux)

## Run

1. Clone this repository.
2. Start Docker.
3. Run `make run` from the project directory to start local development.

## Tests and quality checks

Install the Ruby version in `.ruby-version` and run `bundle install`, then:

```sh
bin/judge-build
RAILS_ENV=test bin/rails db:prepare
export COVERAGE_ROOT="$(mktemp -d)"
bundle exec rspec
bundle exec cucumber --no-profile --strict
bin/rails test
bundle exec ruby test_support/merge_coverage.rb
bin/rubocop --fail-level info
```

CI runs these application suites and requires separate RSpec, Cucumber, and
combined Ruby line coverage of at least 90%, plus zero RuboCop offenses.
Feature owners must add meaningful tests for their acceptance criteria.

See [Quality checks and Definition of Done](docs/quality.md) for report
locations, test authoring, CI activation, and the evidence requiring human review.
