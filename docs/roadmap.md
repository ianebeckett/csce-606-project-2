# Roadmap implementation (US1 / #8)

The roadmap extends the existing Problems page, login, curated data, and judge
records. No new progress table or session lifecycle changes are needed.

`TopicPrerequisite` links `topic_id` to `prerequisite_topic_id`. Foreign keys,
non-null columns, a unique pair index, and a self-link check protect the stored
links. Model validation rejects cycles on creation and updates. Manage links
through validated model writes; bulk SQL bypasses cycle validation. Removing an
empty topic removes its incoming and outgoing links.

`Roadmap.new(user)` loads the topics, problems, prerequisite links, and that
user's distinct Accepted problem IDs once per request. `state(topic)` returns
Locked, In Progress, or Mastered; `unlocked?(topic)` controls access. The
user-confirmed rules are:

- A problem is completed after at least one Accepted submission by that user.
- All prerequisites, including their ancestors, must be mastered to unlock a
  topic. A topic without prerequisites starts In Progress.
- An unlocked, nonempty topic is Mastered when every problem is completed.
  An empty topic remains In Progress. Failed retries do not erase completion.

The seed curriculum requires Arrays & Hashing before Two Pointers, Stack,
Binary Search, and Linked List; Sliding Window requires Two Pointers. This is
the initial curriculum choice for this PR. Adding a problem to a mastered topic
can make it In Progress and relock dependents until the learner solves it.
Existing submissions remain available in personal history.

```text
Signed-in user -> user's Accepted attempts -> Roadmap states
Topics + problems + prerequisite links --------^
Roadmap -> unlocked topic filter -> problem page -> judge submission
Locked topic / problem / submission -> HTTP 403 + prerequisite explanation
```

`RoadmapAccess` applies the same rule to topic filters, direct problem reads,
and submission POSTs before a practice session is created or the judge runs.
Login remains enforced by `ApplicationController`. Topic IDs filter the catalog;
no request parameter can select another user's progress. Both membership roles
use the same server-rendered links and forms.

This reads the already implemented judge result contract (`Attempt::ACCEPTED`),
without introducing a new story dependency or modifying US7's session behavior.
The Cucumber unlock scenario exercises the real Docker judge and database.
Other judge scenarios start with accepted prerequisite fixtures to keep their
focus on execution outcomes.

## Validation

With Ruby, Bundler, and Docker available:

```sh
bundle check
bin/judge-build
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
bundle exec cucumber --strict
bundle exec ruby test_support/merge_coverage.rb
bin/rails test
RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop
bin/brakeman --no-pager
```

The suites enforce 90% coverage separately in `coverage/rspec` and
`coverage/cucumber`; the merge command enforces combined coverage in
`coverage/total`. Docker-backed isolation tests require Linux containers
(Docker Desktop on macOS); they do not run natively on macOS.

For a focused check without Docker, use the commands below. Coverage is disabled
only for these partial runs; they cannot establish the full-suite coverage gates.

```sh
COVERAGE=0 bundle exec rspec spec/models/roadmap_spec.rb spec/models/topic_prerequisite_spec.rb spec/requests/roadmap_spec.rb
COVERAGE=0 bundle exec cucumber features/roadmap.feature --tags 'not @docker' --strict
```

Production deployment, teammate approval, and Sprint demonstration remain
separate release gates; local or hosted test results do not establish them.
