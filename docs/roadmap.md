# Topic Roadmap

## Overview

The topic roadmap directs the user's studies by ensuring they master prerequisite topics
before moving on to more advanced topics.

If a user attempts to access a locked topic, they will be denied, and will be told what
prerequisites they need to complete first.

## Database Design

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

Suppose these are the topic IDs:

'''
1 = Arrays & Hashing
2 = Two Pointers
'''

This prerequisite row:

'''
    topic_id: 2
    prerequisite_topic_id: 1
'''

means “Two Pointers requires Arrays & Hashing.”

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
