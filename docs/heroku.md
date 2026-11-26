# Single-app Heroku deployment

The Container-stack Git deploy uses the repository's `heroku.yml` to build
four images in one Heroku app. The background process is named `queue`
throughout the manifest, Dockerfile, and formation commands:

```text
web      Rails HTTP server
queue    background JudgeSubmissionJob worker
release  database migrations and idempotent judge seeds
judge    two ready, single-use multi-language one-off dynos
```

The `web`, `queue`, and `release` images come from separate targets in the root
`Dockerfile`. The `judge` image comes from `judge/Dockerfile`, with `judge/`
as its build context. It contains `ready.rb`, `warmup.go`, and the isolated
executor, without Rails source. The manifest omits `run`, so each image's
`CMD` applies: in particular, `queue` starts `bundle exec ruby bin/judge-worker`.
The judge formation stays at zero. The queue worker maintains two ready one-off
`judge` dynos, consumes each at most once, and replenishes it when claimed.

This design requires a one-time Container-stack conversion, two judge config
vars, and a persistent Rails secret (`SECRET_KEY_BASE` or credentials configured
through `RAILS_MASTER_KEY`). Buildpack-generated secrets do not carry into the
container image. Never bake these values into an image.
A Git merge cannot grant itself permission to call the Heroku Platform API.

## Data flow

```text
Browser
  -> web dyno saves Attempt as Pending
  -> PostgreSQL delayed job
  -> queue worker checks for jobs every second
  -> claims one already-ready judge; starts a fresh replacement
  -> single-use judge one-off dyno
       stdin: source + fixed runtime + test inputs
       stdout: status + outputs + fixed runtime
  -> queue dyno compares outputs with expected outputs in Rails
  -> queue dyno saves verdict and passed-case count
  -> browser refreshes the saved Attempt
```

The Platform API request overrides environment values whose names contain
`DATABASE`, `PASSWORD`, `SECRET`, `TOKEN`, `_KEY`, or `_URL` with empty strings
in the judge dyno. The `judge` process image contains no Rails source.
The Platform API token, database URLs, Rails secrets, expected outputs, and AI
credentials therefore do not enter the submitted process environment.

Any future config-var secret must use one of those conventional names or the
scrubbing pattern must be updated before deployment.

## Runtime contract

The judge image pins and verifies:

- Ruby 4.0.1 (the judge runtime; Rails uses `.ruby-version`)
- Python 3.15.2
- Go 1.27.3
- C++23 with GCC 16.2.0

Candidates write only the requested method or function. Trusted wrappers supply
Ruby `Set`, common Python names such as `Counter`, common Go imports such as
`sort`, and the GCC `bits/stdc++.h` prelude for C++.

The runner enforces a 15-second compile limit, four seconds per case, bounded
output, and a 55-second whole-process deadline starting when a payload arrives.
A Basic one-off dyno supplies 512 MiB memory and shared 1x CPU.

The worker retires unused connections after 14 minutes. Each prepared dyno has
a 16-minute outer process deadline and an 18-minute Platform API TTL as a
backstop for lost workers or failed cleanup. The worker closes attachments and
stops their exact dyno IDs on retirement. It only marks a dyno ready after the
judge entrypoint sends its readiness marker over the authenticated TLS stream.
Before that marker, it primes Go's standard-library build cache using trusted
imports, with a 30-second warm-up deadline. The cache is private to that fresh
dyno and is never carried across submissions. Submission compilation retains
its separate 15-second deadline.
An empty pool waits at most 40 seconds for replenishment, within the existing
one-minute job deadline, then records `Judge Unavailable` without losing code.

Set `JUDGE_READY_POOL_SIZE=2` for two slots (the default), 1 for one, or 0 to
return to on-demand startup. Only the queue entrypoint starts a pool; web,
release, and administrative Rails processes do not. Keep exactly one queue
dyno. Pool replacement and expiry can temporarily reduce ready capacity.

Heroku Common Runtime dynos can make outbound internet requests. This design
isolates Rails files and config-var values, but does not establish the local
Docker `--network none` condition.

## Deploy through the manifest

The supported path is a Git deployment to the Container stack. Heroku builds
`web`, `queue`, `release`, and `judge` from the same commit, then runs
`./bin/rails db:migrate db:seed` from the release image. No separate
`container:push` or `container:release` is needed for the judge image.
The runner selects that image using Platform API `type: "judge"` and supplies
its own single-use command (`960s ruby /judge/ready.rb` for a prepared dyno).
The judge image retains its `timeout --signal=KILL` entrypoint.

Heroku documents the manifest build contexts and Dockerfile `CMD` fallback in
[Building Docker Images with heroku.yml](https://devcenter.heroku.com/articles/build-docker-images-heroku-yml).
One-off dynos select the image by process type, as described in
[Container Registry & Runtime](https://devcenter.heroku.com/articles/container-registry-and-runtime#one-off-dynos).

### 1. Confirm configuration and budget

Use a clean checkout of the reviewed commit. For the existing app, retain its
Postgres add-on and persistent Rails secret (`SECRET_KEY_BASE`, or credentials
configured through `RAILS_MASTER_KEY`). Never bake secrets into images.

```bash
APP=codecoach
heroku apps:info --app "$APP"
heroku stack:set container --app "$APP"
heroku git:remote --app "$APP"
```

The owner must configure `JUDGE_HEROKU_APP` and `JUDGE_HEROKU_TOKEN`. Reuse the
existing revocable authorization if it is still valid. For a new installation,
create a write-scope authorization and copy its token directly into Config Vars:

```bash
heroku authorizations:create \
  --scope write \
  --expires-in 31536000 \
  --description codecoach-judge
```

Do not put the token in Git, scripts, submitted payloads, dyno commands, or logs.
Record its authorization ID for rotation with `heroku authorizations:revoke`.

```text
JUDGE_HEROKU_APP=codecoach
JUDGE_HEROKU_TOKEN=<revocable OAuth token>
JUDGE_READY_POOL_SIZE=0
```

Keep the pool disabled until the team/app owner approves the ongoing cost below.
The code defaults to two slots when the variable is absent, so set `0`
explicitly if approval is pending. After approval, set it to `2` for the
reviewer's two-slot smoke test, or `1` for a smaller pool. Config changes restart
the worker. A merged PR alone is not budget approval.

### 2. Build and release the reviewed commit

From the clean checkout intended for deployment:

```bash
git push heroku HEAD:main
```

Check the build output for all four images, including `judge/Dockerfile`, and
a successful release phase. This replaces the earlier manual registry flow;
do not release only an old queue or judge image afterward. They share the
readiness protocol and must be deployed together.

### 3. Scale the formation

```bash
heroku ps:type web=basic queue=basic judge=basic --app "$APP"
heroku ps:scale web=1 queue=1 judge=0 --app "$APP"
```

There must be exactly one background queue process. If an earlier deployment
scaled a `worker` process, stop it before starting `queue` so two workers do not
each create a pool. The manifest no longer declares a `worker` process.
`judge=0` disables persistent judge formation dynos; the queue still creates
short-lived one-off judge dynos when requested.

### 4. Verify the actual release

```bash
heroku releases --app "$APP"
heroku ps --app "$APP"
curl --fail "https://codecoach-368f4d281974.herokuapp.com/up"
heroku logs --app "$APP" --dyno queue --num 200
```

For the approved two-slot smoke test:

1. Confirm the release's source commit and that `queue.1` starts
   `bundle exec ruby bin/judge-worker`.
2. Wait for `Judge ready pool: ready=2, target=2` in queue logs. With a pool
   size of zero, absence of this line is expected and does not verify prewarming.
3. Submit a correct Go solution for Contains Duplicate through the app. Check
   Pending followed by Accepted with 6/6 cases and saved source. Record the
   attempt ID, release, and elapsed time.
4. Correlate the submission with `Judge ready pool: claimed` and a subsequent
   return to `ready=2`. Check `heroku ps` for one queue worker and unused judge
   one-offs; do not scale the judge formation above zero.
5. Check Compilation Error and Timeout recovery, retained source, and the
   absence of credentials and compiler diagnostics in application logs.

The 2026-11-11 v18 timings in PR #90 predate this manifest path and are historical
evidence only. They do not validate a new release. On 2026-11-25, read-only
inspection found v24 (`5acc546e`) running `queue.1` with `rake jobs:work` and no
ready judge dynos. The revised manifest still needs the above deployment smoke
test; local tests cannot establish production readiness or fresh latency figures.

## Subsequent deployments

Repeat `git push heroku HEAD:main` from the reviewed checkout. The manifest
builds and releases all four images together. Keep exactly one `queue` dyno.
`JUDGE_READY_POOL_SIZE=0` disables prewarming while preserving on-demand judging.
Roll back the whole release if reverting the queue/judge readiness protocol.

## Rollback

List and roll back releases without deleting production data:

```bash
heroku releases --app "$APP"
heroku releases:rollback <release> --app "$APP"
```

Remove `JUDGE_HEROKU_TOKEN` to fail closed as `Judge Unavailable` if the judge
path must be disabled. Revoke and replace an exposed OAuth authorization.

## Monthly cost estimate

Heroku's [published Common Runtime rates](https://devcenter.heroku.com/articles/usage-and-billing),
checked on 2026-11-25, are approximately $0.01 per Basic dyno hour, capped at $7
per continuously running Basic dyno, and $5 per month for Essential-0 Postgres.
Charges are prorated. Student credits reduce the invoice rather than changing
these resource prices.

| Resource | Monthly estimate before credits |
| --- | ---: |
| One Basic web dyno | $7 |
| One Basic queue dyno | $7 |
| Essential-0 Postgres | $5 |
| Judge process formation at zero | $0 |
| Two continuously ready Basic judge slots | approximately $14–15 |
| Extra execution/replacement overlap | usage-based |

The web, queue, and database base is **$19/month** before credits. Keeping two
judge slots ready continuously brings the estimate to **$33–34/month**, plus
execution/replacement overlap. These are estimates, not spending caps. Setting
the pool size to 0 returns to the $19 base plus on-demand judge usage.

The original on-demand design measured judge submissions at roughly 20-37
seconds. Using the conservative 37-second duration:

```text
one-off cost per submission = $0.01 × 37 / 3600 ≈ $0.000103
```

| Monthly submissions | Estimated one-off cost | Estimated total without a ready pool |
| ---: | ---: | ---: |
| 100 | about $0.01 | about $19.01 |
| 1,000 | about $0.10 | about $19.10 |
| 10,000 | about $1.03 | about $20.03 |

If the team already runs and pays for the Rails web dyno, Postgres, and the
background worker, the incremental judge cost includes the ready slots plus any
execution/replacement overlap. The table above describes on-demand usage only.

## Measured original on-demand deployment

The temporary app below was converted from the `heroku-26` stack to the
`container` stack on 2026-11-09. Release v10 deployed `web`, `release`, and
`judge` images to that one app. The background-judge branch was not merged, so
no queue image was released or scaled in this test.

```text
App:     codecoach-multilang-20261109
URL:     https://codecoach-multilang-20261109-d43fd3325158.herokuapp.com/
Stack:   container
Web:     one Basic dyno
Judge:   one-off only; no idle judge dyno
Health:  /up returned HTTP 200
```

A Rails process in this app used the Platform API and TLS rendezvous path to
create `judge` one-off dynos in the same app. The fixed runtimes returned the
expected outputs for all six `contains-duplicate` cases:

```text
Ruby 4.0.1             ok
Python 3.15.2          ok
Go 1.27.3              ok
C++23 / GCC 16.2.0     ok
```

Invalid syntax in each of those four languages returned `Compilation Error`
with zero outputs and no compiler details. A separate submitted-code probe
returned true for all five checks below without printing any secret value:

```text
DATABASE_URL empty
SECRET_KEY_BASE empty
JUDGE_HEROKU_TOKEN empty
RAILS_MASTER_KEY empty
/rails/config/environment.rb absent
```

After the probes, `heroku ps` showed only `web.1`; no one-off dyno remained.

Official references:

- [Building Docker Images with heroku.yml](https://devcenter.heroku.com/articles/build-docker-images-heroku-yml)
- [Container Registry & Runtime](https://devcenter.heroku.com/articles/container-registry-and-runtime)
- [Platform API Reference](https://devcenter.heroku.com/articles/platform-api-reference)
- [One-Off Dynos](https://devcenter.heroku.com/articles/one-off-dynos)
- [Config Vars](https://devcenter.heroku.com/articles/config-vars)
- [Usage & Billing](https://devcenter.heroku.com/articles/usage-and-billing)
