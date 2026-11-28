# Code Coach

## Getting started

### Use the deployed app

1. Open <https://codecoach-368f4d281974.herokuapp.com/> and select
   **Create account**. Use any email and a password of at least 12 characters.
2. Open **Roadmap & Practice**, pick an unlocked topic, and submit a solution.
3. To try Premium (the Socratic coach and AI code review), select
   **My account**, then **Upgrade to Premium**. This is a free mock toggle.

See the [user guide](docs/user_guide.md) for how the roadmap, practice, and
reviews work.

### Run locally

Install Git, Ruby 4.0.10, Bundler 4.0.19, GNU Make, and Docker (Docker Desktop
on macOS/Windows, or Docker Engine with the Compose plugin on Linux).

1. Clone this repository.
2. Start Docker and confirm `docker info` succeeds without `sudo`.
3. Run `make run`.
4. Open <http://127.0.0.1:3000> and select **Create account**.

`make run` starts PostgreSQL 17 in Docker and prepares the development and test
databases. To enable AI features, run `OPENAI_API_KEY="your-key" make run`.

See [configuration](docs/configuration.md) for database, AI, and Premium
settings, and [troubleshooting](docs/troubleshooting.md) if setup fails.

## Architecture and data model

See the [application architecture](docs/architecture.md) for runtime components
and data flow, and the [database ERD](docs/schema.md) for tables and relationships.

## Running tests

For a quick (~10 second) run during development:

```sh
bin/test-fast
```

Before opening a pull request, run the full suite that CI runs:

```sh
bin/judge-build
docker compose up -d --wait db
RAILS_ENV=test bin/rails db:prepare
export COVERAGE_ROOT="$(mktemp -d)"
JUDGE_INTEGRATION=1 bundle exec rspec
JUDGE_INTEGRATION=1 bundle exec cucumber --no-profile --strict
bin/rails test
bundle exec ruby test_support/merge_coverage.rb
bin/rubocop --fail-level info
```

CI requires separate RSpec, Cucumber, and combined line coverage of at least
90%, plus zero RuboCop offenses. Ordinary RSpec runs skip compiler integration;
ordinary Cucumber language scenarios use scripted process results. The full
commands above include real judging. See [quality checks](docs/quality.md) for
focused test commands, coverage reports, and test guidelines.
