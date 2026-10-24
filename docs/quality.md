# Feature PR quality checks

The **Quality of Work** job in [ci.yml](../.github/workflows/ci.yml) runs the
actual application tests on pull requests, main pushes, and merge groups.
It builds the existing Docker judge image and prepares the test database, then:

- Runs RSpec and fails below 90% application Ruby line coverage.
- Runs strict Cucumber and fails below 90% application Ruby line coverage.
- Runs retained Minitest tests.
- Merges RSpec/Cucumber results and fails below 90% combined coverage.
- Runs RuboCop and fails on any offense.

Coverage includes Ruby files under `app/`, `lib/`, and `judge/`, including
unloaded files. The existing judge collector includes measured Docker executor
coverage. Tests and CI tooling do not contribute to application coverage.
These are suite-wide thresholds, not per-feature scores; reviewers still check
that each story has meaningful happy/sad acceptance tests and unit tests.
JavaScript and template coverage are outside this Ruby measurement.

CI uses a fresh report directory and uploads the individual and combined
reports as `coverage` artifacts, retained for 14 days.

To run locally, start Docker with Linux containers, install the repository's
Ruby and gems, then:

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

After teammate review and merging, make **Quality of Work** a required status
check in main's branch rules to block merges when it fails. A workflow file
alone does not configure that requirement.
See [GitHub status checks](https://docs.github.com/en/pull-requests/reference/status-checks).

Production deployment, user value, acceptance-test quality, and Sprint Review
evidence remain part of each issue's Definition of Done and require human
verification.
