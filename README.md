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

For an existing database, run `bin/rails db:migrate db:seed` to install the
roadmap's prerequisite links. Seeding preserves accounts and submissions.

See the [user guide](docs/user_guide.md) for roadmap states and practice, and
[roadmap implementation](docs/roadmap.md) for model contracts and validation.
