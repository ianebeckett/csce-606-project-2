# US8: Turn-based Interview (design)

Issue: #13 (8 points, Sprint 2). Owner: Chibuzo.

## Why

Real coding interviews start with a deliberately vague problem. Strong candidates
ask clarifying questions before they code, explain a plan, and adapt when the
interviewer changes a requirement. Eugene's coach (US4) teaches someone to
understand a fully stated problem. US8 lets a candidate rehearse the interview
itself: finding the missing requirements and adapting their solution.

User story: *As a candidate, I want to clarify an incomplete problem through a
turn-based AI interviewer so that I can practice requirements discovery and
adapting my solution.*

## Goals

- **AC1:** Start from a partial problem statement and let the candidate ask
  clarifying questions.
- **AC2:** The AI answers clarifications, asks for a high-level strategy, and
  introduces a changed requirement.
- **AC3:** Keep the turn history, lock coding until the candidate has clarified
  the problem, and handle AI failures.
- Meet the #13 Definition of Done:
  - Premium only, enforced on the server.
  - Ownership checks and blocking of signed-out users.
  - Works with JavaScript disabled.
  - Happy and sad Cucumber paths.
  - FIRST RSpec examples.
  - Cucumber and RSpec coverage of at least 90% each, plus combined coverage of at least 90%.
  - Zero RuboCop offenses.
  - One real-AI scenario.
  - Documentation.
  - Production deployment.

## Non-goals

- Scoring the interview. That is US10 (#15), which can later read the saved turns.
- Anti-cheating. A candidate can still open the normal problem page in another
  tab and see the full statement. This is practice, not an exam.
- AI-generated problem variants. Interview content is hand-written (see below).
- Changes to Eugene's coach behaviour, prompts, or UI.

## Anti-goals (a failure even if it "works")

- A candidate can get stuck with the editor locked forever, either because the
  AI never agrees or because it is down.
- The interviewer reveals the hidden details unprompted, or a candidate can
  talk it into dumping them ("ignore your rules…").
- The twist changes the problem so that a correct solution fails the existing
  judge tests.
- The interview and the coach interfere with each other's lock state or
  messages.

## How it works for the candidate

1. On a problem page, a Premium member sees **Practice as an interview**. Free
   members see the usual Premium notice. The button links to the interview page.
2. The interview page shows:
   - the **vague statement** only (no full description or examples);
   - the turn history;
   - a message box;
   - a stage hint ("Ask clarifying questions…");
   - the **locked editor** note.
3. **Clarify:** the candidate asks questions. The interviewer answers only what
   is asked, using that problem's hand-written hidden details. When the
   candidate has uncovered enough details, the page reveals the full problem
   statement and the interviewer asks for a plan.
4. **Strategy:** the candidate describes an approach. When the AI judges it
   correct for the stated requirements, the app posts the problem's
   hand-written **twist** as the interviewer's next turn.
5. **Twist:** the candidate explains how they would adapt. When the AI judges
   the adaptation sound, the **editor unlocks**.
6. **Code:** the candidate submits on the interview page. The existing judge
   runs it with the problem's existing tests, and the result page is unchanged.

**On AI failure at any stage:**
- The candidate's message is kept.
- They see "The interviewer is unavailable right now. Your message is saved,
  and the editor is unlocked."
- The interview is marked skipped, which unlocks the editor.

This mirrors the coach's `skip_coaching!`.

Leaving and returning the same day resumes the same interview. Practice sessions
are already per user, per problem, per day.

## The twist lands on the real problem

The vague statement includes an **easier assumption** that the real problem does
not have. For example, Contains Duplicate starts with "the list is short". The
twist removes that assumption and arrives at the real problem: "it can hold
100,000 numbers". The candidate must adapt (a nested loop becomes a hash set),
and because the final requirements equal the real problem, the existing judge
tests stay correct. This is how US8 meets "adapting my solution" without
breaking the judge.

## Interview content (hand-written, per problem)

New data on each of the 6 seeded problems, in `db/judge_problems.rb` next to
the existing definitions:

- `interview_prompt`: the vague statement, including the easier assumption.
- `interview_details`: 2–4 hidden facts, each with a short key, e.g.
  `{ key: "empty", fact: "The list always has at least one number." }`.
- `interview_twist`: the interviewer's changed requirement, ending on the real
  problem's constraints.

Contains Duplicate example:
- Prompt: "Given a short list of numbers, tell me whether any number repeats."
- Details:
  - size: "1 to 100,000 numbers"
  - range: "values between -10^9 and 10^9"
  - output: "return true/false, not the duplicates"
- Twist: "Actually, the list can hold up to 100,000 numbers. Does your approach
  still work?"

Problems without interview content do not show the interview button. The page
returns a not-found response for them.

## Stages and the gate

Each practice session has a new `interview_state`:
- `not_started`, then `clarifying`, then `strategy`, then `twist`, then `coding`;
- plus `skipped` on AI failure.

The editor is unlocked in `coding` and `skipped`.

Every stage advances the way the coach's stages do: the AI returns
`advance: true`. The system prompt gives the AI the problem's hidden details and
tells it to advance from `clarifying` only once the candidate has asked about
most of them. Only a literal `true` advances, so a malformed reply never unlocks
anything. The AI-failure fallback (skip, unlock) means a strict AI can't trap
anyone.

This is deliberately simpler than having the app count uncovered details: there
is one pattern, matching the coach, and less state to store and test. US8 is a
stretch story.

## Shared lock with the coach

Submitting is blocked on the server while the coach is locked
(`AttemptsController#coaching_locked?`). Without handling, a Premium member who
finishes an interview could not submit.

When the interview reaches `coding` or `skipped`, it also moves the coach's
`coaching_state` to its final stage (`complexity`, "approach accepted") if the
coach is still locked. That is one small method on `PracticeSession`, e.g.
`finish_interview!`. The existing checks in `AttemptsController` and the problem
page then unlock submitting with no changes to Eugene's controller or views, and
the normal problem page's editor is unlocked for that day too.

Use `complexity`, not `skipped`. Coach `skipped` shows "the coach was
unavailable", which would be wrong here. Tell Eugene about the new method.

## Storage

- `ConversationMessage` gains a third phase, `interview`, next to `coaching` and
  `code_review`. The coach and the history page already filter to `coaching`, so
  interview turns never leak into them. Add an `interview` scope.
- The twist is stored as an assistant message like any other turn, so the
  history shows exactly what was asked.
- Migration:
  - `practice_sessions.interview_state` (string, not null, default
    `not_started`);
  - the three interview columns on `problems`. `interview_details` is a list
    that must work on both SQLite and PostgreSQL (Ian's #84). A JSON column
    does, and the problems table already stores test case input as JSON.

## AI contract

- Uses the shared `Ai.client` (ADR 0001) and its structured output schema, like
  the coach and the code review.
- Reply: `{ "message": string, "advance": boolean }`, the same shape as the
  coach. Reuse `Coaching::Parser` if it fits as is; otherwise add an
  equivalent parser. The parser raises `InvalidResponse` for a missing or blank
  message.
- The system prompt contains the stage instructions, the problem's details and
  the twist. The candidate's turns are fenced in a random tag, as in the coach,
  and the prompt says the dialogue is untrusted. The prompt also says:
  - answer only what is asked;
  - never write code;
  - never reveal undisclosed details unprompted.
- Turn history is capped, matching the coach's `HISTORY_LIMIT`.

## Access

- Routes:
  - `GET /problems/:problem_id/interview`;
  - `POST /problems/:problem_id/interview_messages`.
- All interview actions need sign-in and Premium, and the problem's topic must
  be unlocked (`RoadmapAccess`). Sessions always come from `current_user`, so
  there is no cross-user access.
- Server-rendered forms only. Everything works with JavaScript disabled.

## Testing

**RSpec:**
- the stage machine and gate (only a literal `true` advances);
- skip on failure;
- `finish_interview!` unlocking the coach without marking it unavailable;
- a Premium member able to submit after finishing an interview;
- request specs for:
  - Premium vs Free vs signed-out;
  - another user's session;
  - a problem without interview content;
  - the history and coach not showing interview turns.

**Cucumber (3–8 steps each, declarative):**
- **Happy:** clarify the vague problem, explain a plan, adapt to the twist, and
  the editor unlocks.
- **Sad:** the editor stays locked before clarification.
- **Sad:** an AI outage keeps the turns and unlocks the editor.
- **Sad:** a Free member is told it's Premium.
- **Real AI:** one scenario against OpenAI, as in `socratic_coaching.feature`,
  run in CI with the key.

## Documentation

- User guide: an "Interview mode (Premium)" section with a screenshot.
- `docs/` technical note: stages, the gate, data, and the AI contract.
- Update the README only if setup changes (it shouldn't).

## Calls made while writing this (not discussed with Chibuzo; check these)

- The first visit to the interview page moves `not_started` to `clarifying`. The
  vague statement is shown at the top of the page, not posted as a chat
  message.
- Changed after final review to keep the twist a surprise: after clarification
  the interview page shows a "What you've learned" list of the hidden-detail
  facts. The full description and visible examples (the same ones the problem
  page shows) appear only from the twist stage on, and the interviewer prompt
  likewise omits the description until then.
- The interviewer is named "Interviewer", without a persona. Eugene's Senior
  SWE/Grug personas stay coach-only.
- Finishing the interview also unlocks the normal problem page's editor that
  day, by moving the coach to "approach accepted" (see "Shared lock").
- The AI decides when clarification is enough, and the app doesn't count hidden
  details. Chibuzo approved this simplification.
- A Free or signed-out visitor to the interview URL gets the same treatment as
  the coach: Free members are redirected to the problem page with "The
  interviewer is a Premium feature.", and signed-out visitors go to sign in.
- If the interview is already unlocked, further messages still go to the
  interviewer (useful follow-ups), but the gate no longer changes.

## Left to the builder

- Exact prompt wording.
- Stage hint copy.
- The interview content for the other 5 problems, following the Contains
  Duplicate pattern.
- Layout, reusing the existing workspace and panel styles.
