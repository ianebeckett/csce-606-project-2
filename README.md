# Code Coach

## Getting started

There are two ways to use Code Coach: open the deployed app, or clone the
repository and run it on your computer.

### Use the deployed app

1. Open <https://codecoach-368f4d281974.herokuapp.com/> and select
   **Create account**. Use any email and a password of at least 12 characters.
2. Open **Roadmap & Practice**, pick an unlocked topic, and submit a Ruby
   solution. **My submissions** and **My history** show your past attempts.
3. To try Premium features, select **My account** in the header, then
   **Upgrade to Premium**. Premium adds the Socratic coach on each problem and
   **Get AI code review** on each submission. Select **Downgrade to Free** to
   switch back.

Changing plans is a free mock toggle; there is no payment step. See the
[user guide](docs/user_guide.md) for how the roadmap, practice, and reviews work.

### Run locally

#### Install

Use the commands for your OS below, then install the project gems. The project
requires Ruby 4.0.10, Bundler 4.0.19, Git, GNU Make, and Docker with Compose.

##### macOS

Install [Homebrew](https://brew.sh/) and the Xcode Command Line Tools
first (`xcode-select --install` if they are missing), then run:

```sh
brew update
brew install git rbenv ruby-build make openssl@3 libyaml readline libpq vips rust
brew install --cask docker-desktop
export PATH="$(brew --prefix libpq)/bin:$PATH"
```

Open [Docker Desktop](https://formulae.brew.sh/cask/docker-desktop) and finish its
initial setup. The `libpq` PATH entry makes `pg_config` available when building
the `pg` gem; add it to your shell startup file or repeat the export after opening
a new terminal. Continue with [Ruby and project gems](#ruby-and-project-gems).

##### Windows

Use Ubuntu through Windows Subsystem for Linux (WSL2) for the application tools,
and Docker Desktop for Linux containers.

1. If WSL is not installed, run this in **PowerShell as Administrator**, then
   restart Windows if prompted:

   ```powershell
   wsl --install -d Ubuntu
   ```

   Open Ubuntu and create your Linux username/password. For existing WSL setups,
   use `wsl --list --verbose` to check that Ubuntu uses version 2; see
   [Microsoft's WSL setup guide](https://learn.microsoft.com/en-us/windows/wsl/install).
2. Install and open [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/).
   Select the WSL2 backend and enable Ubuntu under **Settings > Resources > WSL
   Integration**. See [Docker's WSL integration guide](https://docs.docker.com/desktop/features/wsl/).
3. In the **Ubuntu terminal**, run the first dependency-install block in
   [Ubuntu](#ubuntu) below. Skip the Docker Engine installation and Linux Docker
   group steps: Docker Desktop supplies Docker and Compose through WSL integration.
4. Continue with [Ruby and project gems](#ruby-and-project-gems) in that Ubuntu
   terminal. Clone the repository inside your Linux home directory (for example,
   `~/codecoach`) and run all subsequent project commands there, including
   `make run`. Open the application URL in your Windows browser.

##### Ubuntu

On Ubuntu 24.04 or later, install rbenv, Ruby build dependencies, PostgreSQL
headers for the `pg` gem, and libvips for image processing:

```sh
sudo apt-get update
sudo apt-get install -y git curl ca-certificates build-essential autoconf \
  rbenv libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev \
  libgmp-dev rustc libpq-dev libvips-dev

mkdir -p "$(rbenv root)/plugins"
if [ -d "$(rbenv root)/plugins/ruby-build" ]; then
  git -C "$(rbenv root)/plugins/ruby-build" pull --ff-only
else
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build"
fi
```

For a fresh Ubuntu Docker installation, use Ubuntu's Engine and Compose packages:

```sh
sudo apt-get install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
```

If Docker is already installed, keep that installation and check
`docker compose version` instead. For Docker's own packages, follow the
[official Ubuntu instructions](https://docs.docker.com/engine/install/ubuntu/).
Then follow [Docker permissions](#docker-permissions-on-linux) so your normal
user can run Docker.

##### Ruby and project gems

On all platforms, use Bash or Zsh (inside Ubuntu on Windows). Run `rbenv init`
once and follow its shell setup instructions, then open a new terminal. Clone
the repository if needed and run the following from its root:

```sh
eval "$(rbenv init -)"
rbenv install -s "$(cat .ruby-version)"
ruby -v
gem install bundler -v 4.0.19
bundle install
```

The repository's `.ruby-version` selects Ruby automatically; no global version
change is needed. If `rbenv install --list-all` does not show the required
version, update ruby-build and retry: for a Git plugin, run
`git -C "$(rbenv root)/plugins/ruby-build" pull --ff-only`; for Homebrew, run
`brew update && brew upgrade ruby-build`. If both are installed, update the Git
plugin too. The version list is local and does not refresh itself. See
[ruby-build setup](https://github.com/rbenv/ruby-build#installation) and its
[build prerequisites](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment).

#### Run

1. Open a terminal in the repository after completing [Install](#install).
2. Start Docker and confirm `docker info` succeeds without `sudo`.
   On Ubuntu with Docker Engine, after joining the `docker` group, run
   `newgrp docker` or log out and back in, then retry. See
   [Docker permissions](#docker-permissions-on-linux).
3. Run `make run` from the project directory to start local development.
4. Open <http://127.0.0.1:3000> and select **Create account**. To try Premium
   features, follow step 3 of [Use the deployed app](#use-the-deployed-app).

Setup starts PostgreSQL 17 in Docker, waits until it is ready, and prepares the
development and test databases. PostgreSQL data persists in a Docker volume.
To stop the database without deleting data, run `docker compose stop db`.

For an existing database, run `bin/rails db:migrate db:seed` to install the
roadmap's prerequisite links. Seeding preserves accounts and submissions.

See the [user guide](docs/user_guide.md) for roadmap states and practice, and
[roadmap implementation](docs/roadmap.md) for model contracts and validation.

## Configuration

### Database

All environments use PostgreSQL. Local defaults are `127.0.0.1:5432`, user and
password `codecoach`, with separate `codecoach_development` and `codecoach_test`
databases. The Docker port is bound only to localhost. If port 5432 is occupied,
use `PGPORT=5433 make run` and use the same `PGPORT` for later Rails/test commands.

To use an existing PostgreSQL server, set `PGHOST`, `PGPORT`, `PGUSER`, and
`PGPASSWORD`, or set `DATABASE_URL`. Setup skips the Docker database when
`PGHOST` or `DATABASE_URL` is set. The local role needs permission to create the
development and test databases. For source builds of the `pg` gem, install
PostgreSQL development headers (`libpq-dev` on Debian/Ubuntu or `libpq` on
Homebrew, with `pg_config` on `PATH`).

Tests use `codecoach_test` by default. `DATABASE_URL` overrides the database
name too: unset it for local tests, or supply a URL for a dedicated test database.
Never run tests with a development or production URL.

In production, set `DATABASE_URL` to the provisioned PostgreSQL connection
string and set `RAILS_MASTER_KEY`. Run
`RAILS_ENV=production bin/rails db:prepare` before serving traffic; the Docker
entrypoint already does this. Kamal also forwards `DATABASE_URL` from the
deployment environment. The local Compose database and its demo credentials
are for development only. This configuration does not provision or deploy a
production database.

Existing `storage/*.sqlite3` files are preserved, but Rails no longer reads them.
`db:prepare` creates a fresh PostgreSQL database; it does not copy SQLite data.
Keep a backup and transfer existing records before switching an installation
that needs to retain accounts or practice history.

### AI

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

Premium is the account role that grants access to AI features. New accounts
start as Free.

#### Change plan from My account

Signed-in members can open **My account** in the header (`/account`) to see
their email and current plan. Select **Upgrade to Premium** or **Downgrade to
Free** to switch plans immediately. This is a mock toggle for development and
demos: there is no payment step. The Premium notices on the problem and
submission pages link to this page through **Upgrade my account**.

#### AI features locally

The coach and AI code review need `OPENAI_API_KEY`, configured as described
above. The Premium role alone does not configure the AI service; without a key,
those features show an "unavailable" message instead.

## Tests and quality checks

Complete [Install](#install), then:

```sh
bin/judge-build
docker compose up -d --wait db
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
