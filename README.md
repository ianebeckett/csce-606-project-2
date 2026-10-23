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

## Judge

The Linux container checks Ruby syntax and reports verdicts in a separate
process from submitted code. Submitted code cannot access that process's
output through inherited file descriptors or `/proc`.
Run `bin/judge-build` after executor changes; `JUDGE_IMAGE` selects an image
for both building and execution without replacing another checkout's image.
