# Feature PR quality checks

The **Quality of Work** job in [ci.yml](../.github/workflows/ci.yml) runs the
actual application tests on pull requests, main pushes, and merge groups.
It starts PostgreSQL 17, builds the existing Docker judge image, and prepares
the PostgreSQL test database, then:

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

## Test speed and external services

AI responses and failures are mocked, including the interview scenario that
exercises the OpenAI adapter through an injected HTTP transport. Tests do not
need an API key or a live AI service.

Executor unit tests inject command results to check compilation errors, runtime
errors, and timeouts without compiling programs or waiting for deadlines. They
also verify that earlier outputs survive a failure and later cases do not run.
Normal Docker tests retain real Ruby execution, runtime failures, linked-list
validation, and container isolation checks. Timeout verdicts use immediate
command/runner doubles; only the low-level process and container termination
checks wait for short 0.15/0.2-second deadlines. Each submission exit has its own
example so its failure and duration are visible separately.

The expensive Python/Go/C++ compiler checks live in
`spec/integration/judge_languages_spec.rb`, tagged `integration`, and are excluded
from ordinary RSpec runs. They still execute real solutions against every
predefined case, including linked lists, and verify real runtime failures.
Run just these checks locally with:

```sh
COVERAGE=0 JUDGE_INTEGRATION=1 bundle exec rspec spec/integration
```

This focused run does not measure suite-wide coverage. CI and full validation
set `JUDGE_INTEGRATION=1` for both RSpec and Cucumber, including real language
judging with coverage enabled.
Real compiler checks may exceed two seconds; normal examples target less than
two seconds on a ready local database and judge image, not a hard CI timing gate.

Acceptance tests retain real Ruby judging and error recovery. In development,
language-selection scenarios delegate to the real Ruby executor with scripted
compiler/process results. Full acceptance validation uses real compilers for
those scenarios. Linked-list result handling, compilation failures, timeouts,
and malformed/excessive output use scripted commands in both modes. This measures
payload construction, wrapper generation, parsing, and failure handling without
launching additional containers or waiting for deadlines. It does not establish
that generated code compiles; the integration checks provide that evidence.

Rating scenarios cover all valid intervals and rejection without state changes.
Due-review scenarios check ownership, date boundaries, ordering, and empty states.
A worker-failure scenario checks that code survives and the error is reported.
These use local database records and immediate doubles, not live external services.

Use `bundle exec cucumber --no-profile --strict` to measure development acceptance
coverage. Use `COVERAGE=0` for a focused run without the suite-wide coverage gate.
Per-file percentages and timing must be checked in fresh reports after test changes;
the additional cases alone do not establish a measured 90% result. CI retains the
full integration runs and unchanged coverage thresholds.

For a quick RSpec development pass, use `bin/test-fast`. It skips the Docker/slow
examples and coverage. Use the full validation commands below before merging.
To profile development runs with the database and judge image ready:

```sh
export COVERAGE_ROOT="$(mktemp -d)"
bundle exec rspec --profile 10
bundle exec cucumber --no-profile --strict --format pretty --format json --out /tmp/codecoach-cucumber-timings.json
```

RSpec lists its slowest examples; Cucumber's JSON records step durations.

## Full validation

CI uses a fresh report directory and uploads the individual and combined
reports as `coverage` artifacts, retained for 14 days.

To run locally, start Docker with Linux containers, install the repository's
Ruby and gems, then:

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

After teammate review and merging, make **Quality of Work** a required status
check in main's branch rules to block merges when it fails. A workflow file
alone does not configure that requirement.
See [GitHub status checks](https://docs.github.com/en/pull-requests/reference/status-checks).

Production deployment, user value, acceptance-test quality, and Sprint Review
evidence remain part of each issue's Definition of Done and require human
verification.
