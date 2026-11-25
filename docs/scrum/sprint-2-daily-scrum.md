# Sprint 2 Daily Scrum

**Sprint:** October 30–November 23, 2026, as clarified by Ian on November 23.
**Tracking:** [Daily Scrum #58](https://github.com/ianebeckett/csce-606-project-2/issues/58)
and [Sprint 2 planning](sprint-2-planning.md).

Source: the Discord excerpt supplied by Ian. Entries below are reported work,
not independent verification of completion or deployment. Dates are retained
without times; undated messages remain separate. The duplicate Salvador
November 10 update is recorded once. October 30–November 1 also appears in the
[Sprint 1 report](sprint-1-daily-scrum.md); the later Sprint boundary clarification
does not establish two separate meetings on those days.

## November 1, 2026

### Han-Ju

- Done: Reviewed and merged Chibuzo's PR.

### Ian Beckett

- Done: Fixed CI by pinning Ruby; updated branch protection rules.
- Next: Deliver mid-project artifacts.

## November 4, 2026

### Ian Beckett

- Done: Created issues and added them to the project tracker.

## November 8, 2026

### Ian Beckett

- Done: Merged the PostgreSQL migration; merged the main-branch CI fix into the
  Sprint 2 documentation PR; deployed the app to Heroku.

### Chibuzo

- Done: Built US8 Turn-based Interview in
  [PR #85](https://github.com/ianebeckett/csce-606-project-2/pull/85), merged main
  into the branch, and reported green CI.
- Next: Get review, merge, and deploy.
- Blocker: A reviewer was needed for #85.

## November 9, 2026

### Han-Ju

- Done: Reviewed #85; fixed the job-queueing bug in
  [PR #44](https://github.com/ianebeckett/csce-606-project-2/pull/44); prototyped
  multi-language support in
  [PR #87](https://github.com/ianebeckett/csce-606-project-2/pull/87).
- Next: Finish #87.

### Mick

- Done: Made the practice-rating prompt appear after submission and opened
  [PR #88](https://github.com/ianebeckett/csce-606-project-2/pull/88).

## November 10, 2026

### Salvador

- Done: Reviewed and approved US5.
- Next: Investigate Ruby syntax highlighting.

### Han-Ju

- Done: Merged asynchronous job processing; had a working multi-language version.
- Next: Determine how to deploy multi-language support on Heroku.

### Chibuzo

- Done: Merged #85 after integrating main and review feedback; reviewed and
  approved #44 and #87.
- Blockers: None reported.

### Mick

- Done: Added the upcoming-reviews dashboard and opened
  [PR #89](https://github.com/ianebeckett/csce-606-project-2/pull/89).
- Next: US5.

## November 11, 2026

### Salvador

- Done: Reviewed and approved #89.

### Ian Beckett

- Done: Deployed the judge to Heroku. Reported provisioning two standby judge
  dynos and reducing submission polling from five seconds to one in
  [PR #90](https://github.com/ianebeckett/csce-606-project-2/pull/90).

### Han-Ju

- Done: Merged multi-language support and helped Ian deploy it on Heroku.

## November 23, 2026

### Ian Beckett

- Done: Approved Eugene's PRs.
- Planning handoff: Recorded the team's
  [Sprint 3 assignments](sprint-3-planning.md).

## Undated updates and feedback

These entries have no calendar date in the supplied excerpt; their position
between dated messages is insufficient to assign one.

- **Ian:** Listed reviewing/merging Eugene's Sprint 2 feature PR and relaxing
  branch protection to speed review and merging, without an explicit completion
  status. The excerpt does not establish the resulting rule configuration.
- **Yung Grug, reporting professor advice:** Recruit real users to find bugs and
  important features; prioritize production deployment and support languages
  beyond Ruby.
- **Yung Grug, reporting a professor demo:** The professor wanted deployment as
  soon as possible, accepted mock payments, and requested C++, Go, and Python
  for his classes. He expressed interest in creating and sharing exam-prep
  problems. This is stakeholder feedback, not approval to add custom problems
  to the current scope or evidence of a formal Sprint Review.
- **Language discussion:** Chibuzo explained the C++/Go classroom use case;
  Han-Ju agreed to work on support. Yung Grug said to defer it if too difficult.
- **Han-Ju, reporting user feedback:** Improve compiler-error messages and
  investigate an AI deployment error. Yung Grug asked its cause; Han-Ju said
  it was unknown and Heroku needed investigation. No resolution is recorded.
- **Sprint 3 allocation:** Han-Ju: indentation and architecture diagrams;
  Salvador: highlighting; Mick: formatter; Chibuzo: C++ compiler errors;
  Ian and Eugene: README. The dated planning record preserves these assignments.

## Evidence still needed

The excerpt does not provide every working day's update, actual all-developer
attendance, a common meeting schedule, or confirmation of the at-most-15-minute
Daily Scrum. Missing next actions and blockers are not inferred. Keep the
Sprint Backlog and daily remaining/completed story points current in
[#25](https://github.com/ianebeckett/csce-606-project-2/issues/25); do not reconstruct
burnup history from these messages. Formal Review and Retrospective records
remain tracked by [#59](https://github.com/ianebeckett/csce-606-project-2/issues/59)
and [#60](https://github.com/ianebeckett/csce-606-project-2/issues/60).
