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
bundle exec rspec
bundle exec cucumber --no-profile --strict
bin/rails test
bundle exec ruby test_support/merge_coverage.rb
bin/rubocop --fail-level info
```

CI requires at least 90% line coverage and zero RuboCop offenses. See
[quality checks](docs/quality.md) for coverage reports and test guidelines.
