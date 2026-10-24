# Code Coach

## Install

- Git
- Ruby 4.0.1
- Bundler 4.0.19
- GNU Make
- Docker Desktop (macOS or Windows) or Docker Engine (Linux)

## Run

1. Clone this repository.
2. Start Docker and confirm `docker info` succeeds without `sudo`.
3. Run `make run` from the project directory to start local development.

For an existing database, run `bin/rails db:migrate db:seed` to install the
roadmap's prerequisite links. Seeding preserves accounts and submissions.

See the [user guide](docs/user_guide.md) for roadmap states and practice, and
[roadmap implementation](docs/roadmap.md) for model contracts and validation.

## Configuration

AI code review uses OpenAI. Set these environment variables before starting the server:

| Variable | Required | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | For AI features | Your OpenAI API key. Without it, AI code review shows "AI code review is unavailable right now" instead of failing. |
| `OPENAI_MODEL` | No | The OpenAI model to use. Defaults to `gpt-6-luna`. |

For example:

```sh
OPENAI_API_KEY="your-key" make run
```

Never commit the key. In production, set it in the hosting provider's environment settings. The test suites never call OpenAI, so CI does not need a key.

### Premium accounts

AI code review is limited to Premium members, and new accounts start as Free. To make a local account Premium:

```sh
bin/rails runner 'User.find_by!(email: "you@example.com").update!(role: "Premium")'
```

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

### Docker permissions on Linux

If `docker info` reports permission denied while Docker is running, add your
user to the Docker Engine installation's `docker` group:

```sh
sudo usermod -aG docker "$USER"
```

Adding your user to the group does not update an existing shell's permissions.
Starting or restarting Docker does not refresh them either. If you already ran
the command above, activate the membership by running these commands one at a
time in your terminal:

```sh
newgrp docker
docker info
make run
```

`newgrp docker` starts a new shell with Docker group access; run the next two
commands in that shell. Continue to `make run` only after `docker info` succeeds.
Run the application as your normal user, without `sudo`.

Alternatively, fully log out of your desktop or SSH session and log back in,
then run `docker info` and `make run`. Opening another terminal in the same
login session may still inherit the old group permissions.

The `docker` group grants root-level privileges. See Docker's official
[Linux post-installation instructions](https://docs.docker.com/engine/install/linux-postinstall/).

## Troubleshooting

**Ruby 4.0.1 fails to install on macOS 26 with a `miniruby` segmentation fault.** This is [Ruby bug #22311](https://bugs.ruby-lang.org/issues/22311): the macOS 27 SDK declares `pipe2()` and `dup3()`, which macOS 26 does not have. Install with:

```sh
ac_cv_func_dup3=no ac_cv_func_pipe2=no rbenv install 4.0.1
```
