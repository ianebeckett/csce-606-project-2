# Single-app Heroku deployment

Code Coach uses one Heroku app with four process images:

```text
web      Rails HTTP server
queue    background JudgeSubmissionJob worker
release  database migrations and idempotent judge seeds
judge    two ready, single-use multi-language one-off dynos
```

The `web`, `queue`, and `release` images come from separate targets in the root
`Dockerfile`. The `judge` image comes from `judge/Dockerfile`. The judge
formation stays at zero. The queue worker maintains two ready one-off `judge`
dynos, consumes each at most once, and replenishes it as soon as it is claimed.

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

- Ruby 4.0.1
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

## One-time setup for the app owner

Run these steps from a clean checkout of team `main` after this pull request and
the background-judge change are merged.

```bash
APP=<ian-heroku-app-name>
```

### 1. Convert the existing app to the Container stack

This retains the app, add-ons, database, config vars, and public domain. It
changes how future releases are built.

```bash
heroku stack:set container --app "$APP"
heroku container:login
```

### 2. Build the four process images

Build `linux/amd64` even when deploying from an Apple Silicon Mac. Disable
provenance and export Docker media types for Heroku Container Registry.

```bash
docker buildx build \
  --platform linux/amd64 \
  --target heroku-web \
  --provenance=false \
  --output type=docker,oci-mediatypes=false \
  --tag "registry.heroku.com/$APP/web" \
  --file Dockerfile .

docker buildx build \
  --platform linux/amd64 \
  --target heroku-queue \
  --provenance=false \
  --output type=docker,oci-mediatypes=false \
  --tag "registry.heroku.com/$APP/queue" \
  --file Dockerfile .

docker buildx build \
  --platform linux/amd64 \
  --target heroku-release \
  --provenance=false \
  --output type=docker,oci-mediatypes=false \
  --tag "registry.heroku.com/$APP/release" \
  --file Dockerfile .

docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --output type=docker,oci-mediatypes=false \
  --tag "registry.heroku.com/$APP/judge" \
  --file judge/Dockerfile judge
```

Push and release all four images:

```bash
docker push "registry.heroku.com/$APP/web"
docker push "registry.heroku.com/$APP/queue"
docker push "registry.heroku.com/$APP/release"
docker push "registry.heroku.com/$APP/judge"

heroku container:release release web queue judge --app "$APP"
```

### 3. Create the Platform API authorization

Use a revocable `write`-scope authorization instead of the account-wide CLI
token. The example expires after one year; use a shorter period for testing.

```bash
heroku authorizations:create \
  --scope write \
  --expires-in 31536000 \
  --description codecoach-judge
```

Copy the token once into the same app's Config Vars and record the authorization
ID for future rotation or revocation:

```text
JUDGE_HEROKU_APP=<same value as APP>
JUDGE_HEROKU_TOKEN=<OAuth token>
JUDGE_READY_POOL_SIZE=2
```

```bash
heroku authorizations:revoke <authorization-id>
```

Do not put the token in Git, shell scripts, submitted-code payloads, database
records, dyno commands, or logs.

### 4. Scale the formation

Do this only after the background-judge dependency and delayed-job migration are
present. Its queue process executes:

```bash
QUEUE=judge bundle exec ruby bin/judge-worker
```

Scale one Basic web dyno and one Basic queue dyno. Keep the judge formation at
zero because it is only a one-off process image.

```bash
heroku ps:type web=basic queue=basic judge=basic --app "$APP"
heroku ps:scale web=1 queue=1 judge=0 --app "$APP"
```

### 5. Verify the release

```bash
heroku apps:info --app "$APP"
curl --fail "<Web URL from heroku apps:info>/up"
heroku ps --app "$APP"
heroku releases --app "$APP"
```

Verify through the browser:

1. Ruby, Python, Go, and C++ correct solutions return Accepted with all cases.
2. Wrong Answer, Compilation Error, Runtime Error, and Timeout are saved.
3. Submission initially returns Pending and does not hold the HTTP request open.
4. The judge formation is zero, while two ready one-off judge dynos remain
   after warm-up. Submissions consume a dyno and trigger a replacement.
5. Rails and Heroku logs contain no credential values or compiler output.

## Subsequent deployments

An ordinary buildpack/Git deploy does not build four Container Registry process
images. Repeat the build, push, and `container:release` commands above, or put
the same commands in the team's deployment workflow after merge. Do not use
`git push heroku main` after the app is converted to the Container stack unless
that workflow is explicitly configured to build all process images.

Deploy the queue and judge images together: the pool requires `judge/ready.rb`
in the judge image. The `JUDGE_READY_POOL_SIZE=0` setting disables prewarming
while preserving on-demand judging. Roll back queue and judge together if
reverting the protocol.

## Rollback

List and roll back releases without deleting production data:

```bash
heroku releases --app "$APP"
heroku releases:rollback <release> --app "$APP"
```

Remove `JUDGE_HEROKU_TOKEN` to fail closed as `Judge Unavailable` if the judge
path must be disabled. Revoke and replace an exposed OAuth authorization.

## Monthly cost estimate

Heroku's published Common Runtime rates observed on 2026-11-09 are approximately
$0.01 per Basic dyno hour, capped at $7 per continuously running Basic dyno, and
$5 per month for Essential-0 Postgres. Charges are prorated. Student credits
reduce the invoice rather than changing these resource prices.

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

- [Container Registry & Runtime](https://devcenter.heroku.com/articles/container-registry-and-runtime)
- [Platform API Reference](https://devcenter.heroku.com/articles/platform-api-reference)
- [One-Off Dynos](https://devcenter.heroku.com/articles/one-off-dynos)
- [Config Vars](https://devcenter.heroku.com/articles/config-vars)
- [Usage & Billing](https://devcenter.heroku.com/articles/usage-and-billing)
