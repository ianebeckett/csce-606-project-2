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
