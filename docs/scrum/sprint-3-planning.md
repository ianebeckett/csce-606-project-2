# Sprint 3 Planning

**Planning allocation recorded:** November 23, 2026, from Ian's supplied team
assignments. **Sprint:** November 23–December 5, 2026; December 5 is a tentative
end target. November 23 is the handoff from Sprint 2. Meeting attendance,
capacity, estimates, and reviewer pairs have not been supplied.

**Tracking:** [Planning #61](https://github.com/ianebeckett/csce-606-project-2/issues/61)
and the [project tracker](https://github.com/users/ianebeckett/projects/3).

## Sprint Goal

Proposed wording for team confirmation: make the deployed multi-language
practice experience easier to edit and debug, and make Code Coach reproducible
and understandable through complete technical and end-user documentation.
This supports the Product Goal of developing interview problem-solving skills
through structured practice, coaching, and retention.

## Selected work

| Owner | Deliverable | Issue |
| --- | --- | --- |
| Han-Ju Chen (`Future-Outlier`) | Indent/outdent and preserve indentation without corrupting code or trapping keyboard focus | [#103](https://github.com/ianebeckett/csce-606-project-2/issues/103) |
| Han-Ju Chen (`Future-Outlier`) | Current system/deployment, class/model, and database diagrams | [#104](https://github.com/ianebeckett/csce-606-project-2/issues/104) |
| Salvador Pruneda (`Spruneda134`) | Syntax highlighting for Ruby, Python, Go, and C++ | [#105](https://github.com/ianebeckett/csce-606-project-2/issues/105) |
| Michael Zhou (`Mick1011`) | Explicit code formatting with undo and safe failure behavior | [#106](https://github.com/ianebeckett/csce-606-project-2/issues/106) |
| Chibuzo Ufomba (`cufomba-tamu`) | Actionable C++ compilation diagnostics in the editor workflow | [#107](https://github.com/ianebeckett/csce-606-project-2/issues/107) |
| Ian Beckett (`ianebeckett`) | README: fresh clone through setup, testing, and production deployment | [#108](https://github.com/ianebeckett/csce-606-project-2/issues/108) |
| Eugene Ku (`Eugene29`) | README navigation and comprehensive end-user guide | [#109](https://github.com/ianebeckett/csce-606-project-2/issues/109) |

The technical/user-guide split is a proposed division of the shared README
assignment. Each issue has measurable acceptance criteria, failure cases,
delivery evidence, and a proposed breakdown into tasks of at most one working
day. Owners should confirm capacity and split larger tasks before committing.
No new story-point estimates are invented or added to parent-story totals.

## Coordination and scope

- Agree editor state/source ownership, keyboard bindings, language selection,
  and failure contracts before integrating indentation, highlighting, formatting,
  and diagnostic locations. Work may proceed in parallel; test the combined
  practice and interview editors with the real judge path.
- Preserve source text, selection/undo where applicable, login/ownership/role
  checks, coaching locks, and manual editing/submission without JavaScript.
  Keep submitted-code execution isolated with time and memory limits.
- Ian and Eugene coordinate README sections and link Han-Ju's diagrams; store
  technical documentation and the user guide in README or docs/. Verify current
  behavior rather than presenting the proposal's ERD or Render plan as deployed
  architecture. The supplied log reports Heroku and PostgreSQL adoption.
- Record custom-problem creation/sharing as professor feedback only; it remains
  outside this Sprint's agreed scope. Mock payments were accepted in the reported
  demo. The reported AI deployment error has no recorded diagnosis or resolution.

## Required deliverables and completion evidence

- **Stories/tests:** Keep essential and optional stories traceable across the
  repository, tracker, and Cucumber features, with measurable SMART/INVEST scope.
  Add independent happy/sad scenarios of 3–8 meaningful user-visible steps and
  unique step definitions; write FIRST RSpec examples at or before applicable
  Ruby implementation. Test JavaScript behavior in a browser and mock AI calls.
- **Quality/deployment:** All tests pass; RSpec, Cucumber, and combined application
  coverage each reach at least 90%; zero RuboCop offenses in Models, Controllers,
  Helpers, and Tests. Use the commands in [quality.md](../quality.md). Record the
  production release commit, URL, and reproducible acceptance checks; passing CI
  or merging alone is not Done. Ruby coverage does not establish browser coverage.
- **Documentation:** Reproduce fresh-clone setup through deployment, publish
  accurate architecture diagrams, and provide a comprehensive user guide for
  implemented workflows and empty/error states. ADRs are recommended (title,
  status, context, decision, consequences); postmortems and debug pointers are
  optional when useful. Validate prose-only work by content/link/render checks
  and teammate walkthroughs, with actual feature-release evidence linked.
- **Git/review:** Use descriptive feature branches and PRs approved by another
  teammate; retain main-branch protection. Follow [CONTRIBUTING.md](../../CONTRIBUTING.md)
  for imperative, capitalized subjects of at most 50 characters and explanatory
  bodies wrapped at 72; comments explain non-obvious reasons and stay current.
- **Scrum/tracker:** Finalize the Sprint Goal during Planning, the first event
  within the Sprint. Confirm dates, capacity, pairs, estimates, and tasks of at
  most one day. Keep the Product Goal, ordered Product Backlog, and Sprint
  Backlog's goal/work/plan visible; update during Planning, Daily Scrums, and
  Review as appropriate. Record real daily product/Sprint story-point burnup or
  burndown, including unchanged days; avoid double-counting tasks.
- **Events/Increments:** Hold Daily Scrum with all developers at the same
  time/place each working day for at most 15 minutes, recording next actions and
  blockers. Review is penultimate, includes the TA or instructor, demonstrates
  usable Increments, and updates the backlog. Retrospective is last and supplies
  concrete improvements for the next Sprint. The project requires at least two
  Sprints, at least one Done Increment per Sprint, and aims for one per developer;
  dates, attendance, collaboration, and completion must have real evidence.

The proposal's feature-specific/optional Scrum discussions and events outside
the Sprint differ from the rubric above; this plan does not certify those
requirements were met. Its generic "default" Definition of Done does not waive
the test, coverage, lint, and deployment gates. Keep the existing review of live
AI tests versus the proposal's mocking requirement explicit in the README task.

Follow-up records: [Daily Scrum #62](https://github.com/ianebeckett/csce-606-project-2/issues/62),
[Review #63](https://github.com/ianebeckett/csce-606-project-2/issues/63),
[Retrospective #64](https://github.com/ianebeckett/csce-606-project-2/issues/64),
[Backlogs/burnups #24](https://github.com/ianebeckett/csce-606-project-2/issues/24)
and [#25](https://github.com/ianebeckett/csce-606-project-2/issues/25),
[Increments #26](https://github.com/ianebeckett/csce-606-project-2/issues/26), and
[required documentation #20](https://github.com/ianebeckett/csce-606-project-2/issues/20).
