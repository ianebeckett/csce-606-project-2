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
4. In another terminal, run one `QUEUE=judge bin/rails jobs:work` worker.

Submissions return as `Pending`; use **Refresh result** to check the verdict.
Active Job uses [Delayed Job](https://github.com/collectiveidea/delayed_job)
to save the queue in SQLite and run submissions outside Puma.
Each submission and its test cases run sequentially, one container at a time.
In production, run `RAILS_ENV=production bin/rails db:prepare`, then one
`RAILS_ENV=production QUEUE=judge bin/rails jobs:work` alongside Puma on the
same host and database, with Docker and the `bin/judge-build` image.
Queued jobs survive restarts; a forcibly stopped job is eligible for retry
after its five-minute lock expires. A stopped worker must be restarted.
