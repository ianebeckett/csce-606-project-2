# 1. Use an injectable AI client

- **Status:** Accepted
- **Date:** 2026-10-22
- **Story:** US3 — AI Code Review (#6)

## Context

US3 needed AI feedback on submitted code before the team had chosen an AI provider. The tests also had to cover AI success and failure without calling a paid API, and the course requires the core flow to keep working when a third-party service fails. US4 (Socratic coaching) and later stories will need AI calls too.

## Decision

AI features talk to the provider through one small contract instead of calling it directly:

```ruby
client.complete(system:, prompt:, schema: nil) # => reply text, or raises Ai::Error
```

- `Ai.client` returns the client set in `config.x.ai_client`. A config initializer sets it to `Ai::OpenAiClient` when `OPENAI_API_KEY` is present, and never in the test environment.
- `Ai::FakeClient` returns a canned reply or error, for tests and local demos.
- `Ai::UnconfiguredClient` is used when no provider is configured, and always raises `Ai::Error`.
- Every provider failure becomes `Ai::Error`. Each feature turns that into its own error (US3 uses `CodeReview::Unavailable`) and shows a friendly message.

In the context of US3, facing an undecided provider and the need to test without API costs, we decided on an injectable AI client to achieve provider independence and fast, free, repeatable tests, accepting that the real HTTP call is only verified manually with a live key.

## Consequences

- Switching providers, or adding a self-hosted model, means writing one class with `complete`. Features don't change.
- CI never needs an API key and never spends money.
- A misconfigured or failing provider shows "unavailable" instead of an error page.
- The real network request in `Ai::OpenAiClient#post` is not covered by automated tests. It was verified manually with a live key on 2026-10-22.
- Provider-specific features beyond `complete` (such as streaming) would need the contract to grow.
