# Background judging

Submissions use Active Job with Delayed Job, a shared PostgreSQL database, and
one judge worker. Puma saves submissions and serves pages. Locally, the worker
executes Ruby, Python, Go, and C++ in isolated Linux Docker containers. Start
Docker Desktop on macOS or Docker Engine on Linux before local judging.

## Run

After the existing application setup, prepare the database and executor:

```sh
docker compose up -d --wait db
bin/rails db:prepare
bin/judge-build
```

Run Puma with the existing `bin/dev` command, and start exactly one worker
in another terminal:

```sh
QUEUE=judge bin/rails jobs:work
```

Puma and the worker must use the same persistent PostgreSQL database and
application version. For the single-app Heroku deployment, the queue dyno calls
the Platform API and each submission runs in a fresh `judge` one-off dyno; it
does not share a Docker daemon with the web process. See `docs/heroku.md` for
the required process images, config vars, scaling, and verification commands.

For a non-Heroku production host using local Docker, set `DATABASE_URL`, prefix
database preparation and the worker command with `RAILS_ENV=production`, and
give the worker access to the same executor image built from that application
version.
`JUDGE_IMAGE` selects the image for both `bin/judge-build` and the worker;
its default is `codecoach-judge:local`.
Run the worker under a process supervisor so it restarts after failure.
These are operating requirements; production deployment is unverified.

`JUDGE_QUEUE_LIMIT` is a positive integer, defaulting to 10. Configure it
consistently in every web process. It limits all `Pending` Attempts across
users, including the submission being judged. The worker count stays one;
increasing the limit increases waiting capacity rather than execution
parallelism.

## Lifecycle

```text
Authenticated browser submits Ruby, Python, Go, or C++
        |
        v
Check roadmap access, coaching, case readiness, and input validation
        |
        v
PostgreSQL transaction: lock queue capacity, then count Pending Attempts
        |
        +--> At capacity: HTTP 503 + Retry-After
        |    Keep source in editor; save no Attempt or job
        |
        v
Save Pending Attempt and Delayed Job in the same transaction
        |
        v
Redirect to saved Attempt; show estimated wait and Refresh result
        |
        v
One worker reserves the job and records judging_started_at
        |
        v
Run through Judge::Runner: local Docker container or Heroku judge one-off dyno
        |
        v
Save verdict, passed/total counts, and any error on Attempt
        |
        v
Delete completed job; reserve the next eligible job

Browser Refresh result reads the owner's saved Attempt
```

Capacity checking, saving, and enqueueing happen inside one PostgreSQL
transaction. A transaction-level advisory lock serializes the capacity check
across competing web processes and releases automatically on commit or
rollback. No database transaction stays open while Docker runs.

Validation failures return HTTP 422 without queueing. An enqueue failure
retains the Attempt and records `Judge Unavailable`, releasing its capacity.
Unexpected execution exceptions also record `Judge Unavailable` and retain
source. Output mismatches continue through the cases; execution errors stop
the remaining cases and preserve the number already passed. Finished
Attempts are skipped on redelivery, and deleted Attempts are discarded.

Queued jobs survive process restarts. A worker must be restarted to resume
processing. Each job has a one-minute deadline; if it exceeds that deadline,
container cleanup still runs, the Attempt records `Judge Unavailable`, and the
completed job row is removed.

## Waiting and rejection

An accepted submission shows the number of pending submissions ahead and
an estimate of when judging will start. A full queue instead suggests when
to retry submitting; it does not reserve a place for the rejected request.
The source remains in that browser's form and is not saved in history.

The estimate assumes one healthy worker. Each earlier submission contributes
the one-minute job deadline. Elapsed time since `judging_started_at` is
subtracted, with a five-second minimum remaining estimate. One five-second
worker poll interval is added. Rejection uses the first running or waiting
submission's remaining estimate because its completion can free one slot.

For example, one unstarted job suggests 65 seconds. If it started ten seconds
ago, the suggestion becomes 55 seconds. A submission behind that running job
and one unstarted job shows 115 seconds; nine unstarted jobs ahead show 545
seconds. These are conservative estimates, not completion-time guarantees.
Worker downtime or delays can extend the wait. Refresh reads current state;
no automatic submission or JavaScript is needed.

The HTTP 503 status and `Retry-After` follow
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-503-service-unavailable).
See [Delayed Job](https://github.com/collectiveidea/delayed_job) for worker
operation, locking, and retries, and
[Active Job](https://guides.rubyonrails.org/active_job_basics.html) for job
serialization and adapters.
