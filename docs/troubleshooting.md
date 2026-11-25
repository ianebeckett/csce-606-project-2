# Troubleshooting

## Docker permission denied on Linux

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
commands in that shell. Continue to `make run` only after `docker info`
succeeds. Run the application as your normal user, without `sudo`.

Alternatively, fully log out of your desktop or SSH session and log back in,
then run `docker info` and `make run`. Opening another terminal in the same
login session may still inherit the old group permissions.

The `docker` group grants root-level privileges. See Docker's official
[Linux post-installation instructions](https://docs.docker.com/engine/install/linux-postinstall/).

## Port 5433 already in use

Run `PGPORT=5434 make run` and use the same `PGPORT` for later Rails and test
commands. See [configuration](configuration.md#database).

## Database password authentication fails even though Compose reports healthy

Check `docker compose port db 5432`: it should print `127.0.0.1:5433` with
the default configuration. Rails and Compose must use the same `PGPORT`.
A healthy container does not prove Rails is connecting to it; another local
PostgreSQL server may be answering on port 5432. If the container has no
published port, recreate it while keeping its data volume:

```sh
docker compose up -d --wait --force-recreate db
RAILS_ENV=test bin/rails db:prepare
```

## Ruby fails to install on macOS 26 with a `miniruby` segmentation fault

This is [Ruby bug #22311](https://bugs.ruby-lang.org/issues/22311): the macOS
27 SDK declares `pipe2()` and `dup3()`, which macOS 26 does not have. Install
with:

```sh
ac_cv_func_dup3=no ac_cv_func_pipe2=no rbenv install 4.0.10
```
