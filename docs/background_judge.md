# Background judging

Ruby submissions use Active Job with Delayed Job, a shared SQLite database,
and one judge worker. Puma saves submissions and serves pages; the worker
executes submitted Ruby in isolated Linux Docker containers. Start Docker
Desktop on macOS or Docker Engine on Linux before judging.

## Run

After the existing application setup, prepare the database and executor:

```sh
bin/rails db:prepare
bin/judge-build
```

Run Puma with the existing `bin/dev` command, and start exactly one worker
in another terminal:

```sh
QUEUE=judge bin/rails jobs:work
```

For production, prefix database preparation and the worker command with
`RAILS_ENV=production`. Puma and the worker must use the same persistent
SQLite database, application version, Docker daemon, and executor image.
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
Authenticated browser submits Ruby
        |
        v
Check roadmap access, coaching, case readiness, and input validation
        |
        v
SQLite transaction: count Pending Attempts
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
Run cases sequentially: create container -> execute -> remove container
        |
        v
Save verdict, passed/total counts, and any error on Attempt
        |
        v
Delete completed job; reserve the next eligible job

Browser Refresh result reads the owner's saved Attempt
```

Capacity checking, saving, and enqueueing happen inside Rails' SQLite
`BEGIN IMMEDIATE` transaction. Competing web processes serialize that check
through the database. No database transaction stays open while Docker runs.
A migration to another database needs its own concurrency verification and
locking; this implementation does not claim PostgreSQL support.

Validation failures return HTTP 422 without queueing. An enqueue failure
retains the Attempt and records `Judge Unavailable`, releasing its capacity.
Unexpected execution exceptions also record `Judge Unavailable` and retain
source. Output mismatches continue through the cases; execution errors stop
the remaining cases and preserve the number already passed. Finished
Attempts are skipped on redelivery, and deleted Attempts are discarded.

Queued jobs survive process restarts. A worker must be restarted to resume
processing. A forcibly stopped job can be reserved again after its
five-minute lock expires; its start timestamp is reset when it executes
again. This provides retries rather than exactly-once execution. Transient
database errors while loading an Attempt use Delayed Job's retry schedule.
Repeated failures can exhaust Delayed Job's retries. Failed jobs are retained
with `failed_at` and `last_error` for operator investigation rather than
silently removed. They are not automatically executed again; a `Pending`
Attempt continues to consume capacity until the failure is repaired. After
repair, stop the worker and retry only the identified failed job by resetting
its `attempts`, `failed_at`, `locked_at`, `locked_by`, and `run_at`, or mark its
Attempt `Judge Unavailable` and remove that job. Do not delete jobs
indiscriminately or reset locks while a worker may still be executing them.

## Waiting and rejection

An accepted submission shows the number of pending submissions ahead and
an estimate of when judging will start. A full queue instead suggests when
to retry submitting; it does not reserve a place for the rejected request.
The source remains in that browser's form and is not saved in history.

The estimate assumes one healthy worker. Each earlier submission contributes
its case count times the four-second execution deadline plus three seconds
for cleanup per case. Elapsed time since `judging_started_at` is subtracted,
with a five-second minimum remaining estimate. One five-second worker poll
interval is added. Rejection uses the first running or waiting submission's
remaining estimate because its completion can free one slot.

For example, six cases contribute 42 seconds. A full queue whose first
submission has not started suggests retrying in about 47 seconds. If it
started ten seconds ago, the suggestion becomes about 37 seconds. A queued
submission behind that one and another seven-case submission has an
86-second estimated wait. These are conservative workload estimates, not
measured completion predictions or guarantees. Docker delays, changed case
data, worker downtime, and retries can extend the wait or change ordering.
Refresh reads current state; no automatic submission or JavaScript is needed.

The HTTP 503 status and `Retry-After` follow
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-503-service-unavailable).
See [Delayed Job](https://github.com/collectiveidea/delayed_job) for worker
operation, locking, and retries, and
[Active Job](https://guides.rubyonrails.org/active_job_basics.html) for job
serialization and adapters.
