# Configuration

## Database

All environments use PostgreSQL. `make run` starts PostgreSQL 17 in Docker,
waits until it is ready, and prepares the development and test databases.
Data persists in a Docker volume. To stop the database without deleting data,
run `docker compose stop db`.

Local defaults are `127.0.0.1:5433`, user and password `codecoach`, with
separate `codecoach_development` and `codecoach_test` databases. The Docker
port is bound only to localhost. Port 5433 avoids a system PostgreSQL server
on the usual port 5432. If port 5433 is occupied, use `PGPORT=5434 make run`
and use the same `PGPORT` for later Rails/test commands.

For an existing database, run `bin/rails db:migrate db:seed` to install the
roadmap's prerequisite links. Seeding preserves accounts and submissions.

### Using your own PostgreSQL server

Set `PGHOST`, `PGPORT`, `PGUSER`, and `PGPASSWORD`, or set `DATABASE_URL`.
Setup skips the Docker database when `PGHOST` or `DATABASE_URL` is set. The
local role needs permission to create the development and test databases. Set
`PGPORT=5432` for an existing server using the standard PostgreSQL port. For
source builds of the `pg` gem, install PostgreSQL development headers
(`libpq-dev` on Debian/Ubuntu or `libpq` on Homebrew, with `pg_config` on
`PATH`).

### Test database

Tests use `codecoach_test` by default. `DATABASE_URL` overrides the database
name too: unset it for local tests, or supply a URL for a dedicated test
database. Never run tests with a development or production URL.

### Production

Set `DATABASE_URL` to the provisioned PostgreSQL connection string and set
`RAILS_MASTER_KEY`. Run `RAILS_ENV=production bin/rails db:prepare` before
serving traffic; the Docker entrypoint already does this. Kamal also forwards
`DATABASE_URL` from the deployment environment. The local Compose database and
its demo credentials are for development only. This configuration does not
provision or deploy a production database. See [Heroku deployment](heroku.md)
for the hosted setup.

### Migrating from SQLite

Existing `storage/*.sqlite3` files are preserved, but Rails no longer reads
them. `db:prepare` creates a fresh PostgreSQL database; it does not copy SQLite
data. Keep a backup and transfer existing records before switching an
installation that needs to retain accounts or practice history.

## AI

The Socratic coach and AI code review use OpenAI. Set these environment
variables before starting the server:

| Variable | Required | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | For AI features | Your OpenAI API key. Without it, AI features show an "unavailable" message instead of failing. |
| `OPENAI_MODEL` | No | The OpenAI model to use. Defaults to `gpt-6-luna`. |

```sh
OPENAI_API_KEY="your-key" make run
```

Never commit the key. In production, set it in the hosting provider's
environment settings. The test suites never call OpenAI, so CI does not need a
key.

## Premium accounts

Premium is the account role that grants access to AI features. New accounts
start as Free.

Signed-in members can open **My account** in the header (`/account`) to see
their email and current plan. Select **Upgrade to Premium** or **Downgrade to
Free** to switch plans immediately. This is a mock toggle for development and
demos: there is no payment step. The Premium notices on the problem and
submission pages link to this page through **Upgrade my account**.

The Premium role alone does not configure the AI service; without
`OPENAI_API_KEY`, the coach and AI code review show an "unavailable" message.
