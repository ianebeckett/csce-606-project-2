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

## Configuration

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

AI code review is limited to Premium members, and new accounts start as Free. To make a local account Premium:

```sh
bin/rails runner 'User.find_by!(email: "you@example.com").update!(role: "Premium")'
```

## Troubleshooting

**Ruby 4.0.1 fails to install on macOS 26 with a `miniruby` segmentation fault.** This is [Ruby bug #22311](https://bugs.ruby-lang.org/issues/22311): the macOS 27 SDK declares `pipe2()` and `dup3()`, which macOS 26 does not have. Install with:

```sh
ac_cv_func_dup3=no ac_cv_func_pipe2=no rbenv install 4.0.1
```
