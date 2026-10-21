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
bin/quality
bin/rubocop --fail-level info . bin/quality .github/scripts .github/spec
```

`bin/quality` runs RSpec, Cucumber, and retained Minitest tests. It requires
separate RSpec, Cucumber, and combined Ruby line coverage of at least 90%.
Empty RSpec/Cucumber suites fail. Feature owners must add meaningful tests;
the test setup alone does not establish feature completion.

See [Quality checks and Definition of Done](docs/quality.md) for report
locations, test authoring, CI activation, and the evidence requiring human review.
