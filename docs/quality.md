# Quality checks and Definition of Done

An Increment is usable product work that meets the Definition of Done.
The issue-specific acceptance criteria describe the user value to deliver.
The release gates below apply before marking a story Done or counting its
points. The supplied Project 2 rubric defines the coverage, lint, and production
requirements; the [Scrum Guide](https://scrumguides.org/scrum-guide.html#increment)
explains Increments and permits multiple releases within a Sprint.

## Automated checks

The `Quality of Work` job in
[quality.yml](../.github/workflows/quality.yml) runs on pull requests, pushes to
main, and merge groups on a GitHub-hosted Ubuntu runner. The judge tests require
Docker with Linux containers. On macOS, use Docker Desktop; on Linux, use Docker Engine. Install the repository's Ruby version
and bundle and start Docker before running the full suite.

```sh
bundle check
bin/judge-build
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec --options /dev/null .github/spec
bin/quality
bin/rubocop --fail-level info . bin/quality .github/scripts .github/spec
```

- Gate regression specs test coverage boundaries, result merging, missing
  evidence, and empty/pending/failed tests. They are tooling tests, run separately
  from the application suite and excluded from application coverage.
- `bin/quality` runs `bundle exec rspec`, `bundle exec cucumber` with strict
  results and no profile filters, and `bin/rails test`. It adds JSON reporters
  to RSpec/Cucumber and fails on empty suites, pending examples, non-passing
  scenario steps, missing/invalid reports, or nonzero command exits.
- RSpec, Cucumber, and their combined report must each reach **90% Ruby line
  coverage**. Each suite starts SimpleCov before loading application code.
  All Ruby files under `app/`, `lib/`, and `judge/`, including unloaded files,
  are in scope. The existing Docker coverage collector merges measured executor
  coverage back into each suite. Tests, CI tooling, dependencies, and Rails
  configuration are outside that denominator. JavaScript and template coverage are not measured by this
  Ruby coverage gate; user-visible acceptance checks still need to exercise
  the rendered flows.
- Each full run uses a fresh `tmp/quality/run-*/` directory. Separate suite
  result caches prevent cross-suite or stale results from lifting a score.
  Combined coverage merges executed lines, rather than averaging percentages.
  Minitest remains a regression check and cannot replace RSpec or Cucumber.
- RuboCop runs across the repository, including Models, Controllers, Helpers,
  and Tests. Explicit paths also include the extensionless quality runner and
  hidden CI scripts/specs. `--fail-level info` fails on any offense severity.

The runner continues after individual suite failures so available evidence is
retained. The GitHub artifact `quality-evidence` contains the JSON test reports,
`summary.txt`, and `rspec/`, `cucumber/`, and `total/` HTML reports plus
hidden SimpleCov result files. Artifacts are retained for 14 days; preserve
needed evidence with the release/Sprint records before it expires.

`bin/ci` includes the same gate tests, test database preparation, quality
runner, and lint, alongside the existing security checks. It also runs the
repository's existing setup command. The workflow runs serial suites against
the current SQLite test configuration; a future database/backend change must
update CI alongside the application.

## Writing feature tests

The judge feature supplies application RSpec examples and Cucumber scenarios.
This workflow preserves those tests and their Docker executor coverage. Future
features must add meaningful tests and keep each threshold at 90% or higher.
Empty suites fail even when eager loading produces high line coverage. Tooling
tests and Rails boot alone do not prove a story works.

Put RSpec examples under `spec/**/*_spec.rb`. The default RSpec options load
`rails_helper`, which starts coverage before Rails, retains the judge helpers,
and enables transactional fixtures. Empty suites fail. Run the application suite:

```sh
bundle exec rspec
```

Put Cucumber features under `features/*.feature` and their step definitions
under `features/step_definitions/`. The support environment uses Capybara's
`rack_test` driver, so core flows run without JavaScript, and DatabaseCleaner
transactions isolate scenarios. A JavaScript browser driver is not configured.
Run acceptance tests:

```sh
bundle exec cucumber --strict
```

Direct suite commands write individual reports under `coverage/`; use
`bin/quality` for the complete, fresh three-report gate and empty-suite
validation. Do not treat a selected subset of tests as full-suite evidence.

Associate scenarios with their issue/story and acceptance criteria. Cover
happy paths and relevant errors, empty states, permissions, ownership, and
recovery. Keep scenarios independent, meaningful, and 3–8 user-visible steps
with unambiguous definitions. RSpec examples follow FIRST: fast, independent,
repeatable, self-validating, and written at or before implementation. Mock
third-party AI success/failure responses; exercise real upstream application
features when validating integration.

## Activation and human evidence

Adding a workflow locally does not activate GitHub enforcement. Merge it
through a teammate-approved PR, then make **Quality of Work** a required
status check in the main branch rules after its first run. Verify the actual
rule and check source. Repository rules must also prevent direct commits and
require another teammate's review. This change does not alter those settings.
See [GitHub's status-check documentation](https://docs.github.com/en/pull-requests/reference/status-checks).

Before a product story is Done, record:

1. Its usable user-facing result and acceptance evidence, including real
   inter-feature integration and any required error recovery/access checks.
2. All passing tests, separate acceptance/unit/combined coverage each ≥90%,
   and zero required-scope RuboCop offenses at the delivered revision.
3. A teammate-approved PR and current technical/end-user documentation.
4. The production release commit, URL, and reproducible acceptance checks.
   A passing workflow, HTTP health response, or merge is insufficient proof
   of a usable production feature.

At the Sprint Review, present the sum of the Increments and record real
TA/instructor attendance, feedback, and Product Goal progress. Multiple
Increments may be created and released within a Sprint; release need not
wait for the Review. Deliver at least one usable Increment per Sprint and aim
for one per developer, within the agreed timeframe. There is no fixed ideal
count. Record missed targets honestly and award points only to Done work.

Scrum/documentation issues need their own real artifacts and evidence for
associated product Increments. Meeting notes do not need application tests;
unpointed process work does not become a separate product Increment. Recurring
obligations remain open until all required occurrences are evidenced.

No automated deployment is added here: the proposal's Render/PostgreSQL plan
has not been configured in this checkout. Reviewers must verify the selected
production environment, usability, scenario quality, and actual Scrum evidence.

Implementation references:
[SimpleCov configuration](https://github.com/simplecov-ruby/simplecov/blob/main/docs/Configuration.md),
[Cucumber Rails](https://github.com/cucumber/cucumber-rails), and
[RSpec Rails](https://github.com/rspec/rspec-rails).
