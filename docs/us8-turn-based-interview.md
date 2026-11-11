# US8: Turn-based interview (technical note)

Full design: [superpowers/specs/2026-11-08-us8-turn-based-interview-design.md](superpowers/specs/2026-11-08-us8-turn-based-interview-design.md).

## Stages and the gate

`practice_sessions.interview_state` moves through `not_started`, `clarifying`,
`strategy`, `twist`, `coding`, with `skipped` as the failure exit. The editor is
unlocked in `coding` and `skipped` (`PracticeSession#interview_locked?`).

The first visit to the interview page calls `start_interview!`
(`not_started` to `clarifying`). Each message goes to
`Interviewing::Interviewer`; if the reply has `advance` equal to a literal
`true`, `advance_interview!` moves one stage. Anything else (false, missing,
`"true"`) leaves the stage alone. Entering `twist` posts the problem's
`interview_twist` as an assistant message; entering `coding` calls
`finish_interview!`. Once unlocked, further messages still reach the
interviewer but the gate no longer changes.

On any AI failure (`Ai` errors, `Coaching::Parser::InvalidResponse`), the
candidate's message is kept and `skip_interview!` unlocks the editor, so
nobody is stuck.

## What the page and the prompt reveal

The problem's description states the real, post-twist constraints, so it is
hidden until the twist. `PracticeSession#interview_twist_revealed?` is true for
`twist`, `coding` and `skipped`. Before that, the page shows the vague
statement and, from `strategy` on (`interview_clarified?`), a "What you've
learned" list of the hidden-detail facts. From the twist on it shows the full
description and examples. The interviewer prompt follows the same rule: the
full description is sent only when the twist is revealed.

`advance_interview!` runs inside `with_lock`, so concurrent sends cannot
double-advance a stage or post the twist twice.

## Shared coach unlock

`AttemptsController` blocks submissions while the coach is locked.
`PracticeSession#finish_interview!` (run on entering `coding` or `skipped`)
moves a still-locked coach to `complexity` ("approach accepted"), never to the
coach's `skipped`, which would show "the coach was unavailable". No change to
Eugene's controllers, prompts or views was needed. Eugene should know the
method exists.

## Data

- `problems.interview_prompt` (text): the vague statement, with an easier
  assumption the real problem lacks.
- `problems.interview_details` (JSON list of `{key, fact}`): hidden facts the
  interviewer reveals only when asked. JSON works on SQLite and PostgreSQL.
- `problems.interview_twist` (text): the changed requirement; it ends on the
  real problem's constraints, so existing judge tests stay valid.
- `practice_sessions.interview_state` (string, not null, default `not_started`).
- `ConversationMessage` phase `interview` (with an `interview` scope). The
  coach and history page filter to `coaching`, so interview turns do not leak.

Content lives in `db/judge_problems.rb`. Problems without it hide the button
and the interview URL returns 404.

## AI contract

`Interviewing::Interviewer` uses the shared `Ai.client` (ADR 0001) and parses
`{ "message": string, "advance": boolean }` with `Coaching::Parser` (blank or
missing message raises `InvalidResponse`). The system prompt holds the stage
instructions and hidden details; the twist appears only from the `twist` stage
on. The candidate's turns are fenced in a random tag and declared untrusted;
the prompt says to answer only what is asked, never write code, and never
reveal undisclosed details. History is capped like the coach's.

## Access

`GET /problems/:problem_id/interview` and
`POST /problems/:problem_id/interview_messages`. Sign-in comes from
`ApplicationController`, topic unlock from `RoadmapAccess`, Premium from the
`InterviewAccess` concern (Free members are redirected with "The interviewer is
a Premium feature."). Sessions always come from `current_user`. Forms are
server-rendered and work without JavaScript.
