# Application architecture

Code Coach is a server-rendered Rails application with a separate background
worker for judging submitted code. PostgreSQL stores both learning data and
the Delayed Job queue. This diagram describes the current repository's
implementation and configuration, not a verification of the live deployment.

## Runtime components

```text
┌───────────────────────────────────────┐
│ Browser                               │
│ HTML forms, navigation, code editor   │
│ Optional JavaScript verdict polling   │
└───────────────────┬───────────────────┘
                    │ HTTP requests / HTML or JSON responses
                    ▼
┌───────────────────────────────────────┐                      ┌───────────────────────────────────────┐
│ Rails web process (Puma)              │                      │ OpenAI Responses API                  │
│ Controllers, ERB views, services      │◄─── HTTPS / JSON ───►│ Coaching, interviews, code review,    │
│ Login, ownership, Premium checks      │                      │ and completed-session feedback        │
│ Roadmap, practice, history, reviews   │                      └───────────────────────────────────────┘
│ Active Record / Judge::Queue          │
└───────────────────┬───────────────────┘
                    │ SQL: learning data + enqueue jobs
                    ▼
┌───────────────────────────────────────┐                      ┌───────────────────────────────────────┐
│ PostgreSQL                            │                      │ One judge queue worker                │
│ Accounts, curriculum, sessions,       │◄─────── SQL ────────►│ Delayed Job / JudgeSubmissionJob      │
│ attempts, dialogue, review schedules  │                      │ Reserve jobs; load attempts and cases │
│ delayed_jobs                          │                      │ Compare outputs; save verdicts        │
└───────────────────────────────────────┘                      │ Judge::Submission / Judge::Runner     │
                                                               └───────────────────┬───────────────────┘
                                                                                   │ Source + test inputs
                                                                                   │ Outputs + status
                                                                                   ▼
                                                               ┌───────────────────────────────────────┐
                                                               │ Submitted-code executor               │
                                                               │ Local Docker container, Heroku        │
                                                               │ one-off dyno, or remote HTTPS service │
                                                               │ Ruby / Python / Go / C++              │
                                                               └───────────────────────────────────────┘
```

Connections carry requests and responses. The executor runs submitted code
outside the Rails processes. Expected outputs stay in the worker, where
[`Judge::Submission`](../app/services/judge/submission.rb) compares them with
the executor's returned outputs and saves the verdict and passed-case count.
The executor does not read or write the application's database directly.

## Request and data flow

1. The browser submits ordinary Rails forms. Controllers enforce login,
   ownership, roadmap access, and feature-specific Premium checks. Active
   Record reads and writes PostgreSQL; views render the response. Core flows
   work without JavaScript. The submission page can optionally poll the
   owner's attempt as JSON, or the user can refresh it manually.
2. On code submission, [`Judge::Queue`](../app/services/judge/queue.rb) checks
   capacity under a PostgreSQL advisory lock, then saves the pending attempt
   and enqueues its job in the same transaction. A full queue rejects the
   submission while retaining the source in the form.
3. The worker reserves the job, executes it through the selected runner, and
   saves the result. The browser reads that saved result through Rails.
   Execution happens after the enqueue transaction has finished; the web
   request does not wait for judging. See [background judging](background_judge.md)
   for queue limits, deadlines, and failure handling.
4. Coaching, interviews, code review, and session feedback call the injectable
   [`Ai.client`](../app/services/ai.rb) synchronously within the web request.
   [`Ai::OpenAiClient`](../app/services/ai/open_ai_client.rb) sends HTTPS requests
   to the Responses API when configured. Messages, reviews, and feedback are
   persisted through the Rails models. Missing configuration or provider
   failures leave saved code and dialogue intact. Tests inject fake clients;
   see the [AI client decision](adr/0001-injectable-ai-client.md).
5. Rating completed practice updates the session and review schedule in a
   transaction. Premium session feedback is requested afterward, so an AI
   failure does not undo the saved rating or next review date.

The [database ERD](schema.md) shows the tables, foreign keys, and cardinalities.

## Judge backends and deployment

[`Judge::Runner.build`](../app/services/judge/runner.rb) selects a backend in
the following order:

| Selection condition | Executor and connection |
| --- | --- |
| Either `JUDGE_HEROKU_APP` or `JUDGE_HEROKU_TOKEN` is present | `HerokuDynoRunner`: Platform API launches single-use judge dynos; an attached TLS stream carries inputs and outputs. Both settings must be valid to execute. |
| Otherwise, production environment or `JUDGE_URL` is present | `RemoteRunner`: authenticated HTTPS request to `JUDGE_URL`, using `JUDGE_TOKEN`. Missing or invalid configuration returns `Judge Unavailable`. |
| Otherwise | `DockerRunner`: a local container receives JSON on stdin and returns JSON on stdout. |

The local [Compose file](../compose.yaml) provides PostgreSQL; Rails and the
judge worker run as separate processes. Local judge containers disable
networking and use a read-only root filesystem, an unprivileged user, and
memory, CPU, process, and execution-time limits.

The [Heroku manifest](../heroku.yml) builds separate `web`, `queue`, `release`,
and `judge` images. The release process migrates and seeds the shared database.
The queue image runs [`bin/judge-worker`](../bin/judge-worker), which can maintain
a pool of fresh, single-use judge dynos. The judge image excludes Rails source;
the runner clears environment variables matching its sensitive-name pattern.
Heroku judging does not provide the local Docker backend's disabled networking.
See [Heroku deployment](heroku.md) for configuration and live-release checks,
and [configuration](configuration.md) for local database and AI settings.
