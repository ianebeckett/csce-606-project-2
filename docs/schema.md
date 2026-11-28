# Database schema

This ERD reflects the implemented tables and columns in [db/schema.rb](../db/schema.rb).
The views below repeat some tables to keep connections readable; `...` means
that the table's fields are shown in another view. All tables include an `id`
primary key, and all columns are shown in their full table view.

`PK` = primary key; `FK` = foreign key. Each endpoint uses `(min,max)`
notation: the label beside a table counts related rows per row of that table.
`N` means many; arrows point to the referenced parent's `id`.

- `(0,N)` beside a parent: each parent can have zero or many children.
- `(1,1)` beside a child: each child must reference exactly one parent.
- `(0,1)` beside `conversation_messages` on its `attempt_id` connection:
  each message can reference zero or one attempt.

For example, a user can have `(0,N)` practice sessions, while each practice
session belongs to `(1,1)` user. These cardinalities describe the stored
relationships; the judge separately requires at least five test cases before
a problem can be judged.

## Topics and problems

```text
                                                                                ┌─────────────────┐
                                   ┌───────────────────┐                        │    test_cases   │
┌────────────┐                     │      problems     │                        ├─────────────────┤
│   topics   │                     ├───────────────────┤                        │ id (PK)         │
├────────────┤                     │ id (PK)           ├◄(0,N)────────────(1,1)─┤ problem_id (FK) │
│ id (PK)    ├◄(0,N)─────────(1,1)─┤ topic_id (FK)     │                        │ input           │
│ name       │                     │ slug              │                        │ expected_output │
│ position   │                     │ title             │                        │ position        │
│ created_at │                     │ description       │                        │ visible         │
│ updated_at │                     │ difficulty        │                        │ created_at      │
└────────────┘                     │ source_url        │                        │ updated_at      │
                                   │ method_name       │                        └─────────────────┘
                                   │ input_kind        │
                                   │ comparison        │
                                   │ starter_code      │
                                   │ created_at        │
                                   │ updated_at        │
                                   │ interview_prompt  │
                                   │ interview_details │
                                   │ interview_twist   │
                                   └───────────────────┘
```

## Topic prerequisites

Both references point to `topics`: the left is the dependent topic, and the
right is its prerequisite. The join table represents a directed many-to-many
relationship between topics.

```text
                              ┌────────────────────────────┐
┌─────────┐                   │    topic_prerequisites     │
│  topics │                   ├────────────────────────────┤                    ┌─────────┐
├─────────┤                   │ id (PK)                    │                    │  topics │
│ id (PK) ├◄(0,N)───────(1,1)─┤ topic_id (FK)              │                    ├─────────┤
│ ...     │                   │ prerequisite_topic_id (FK) ├─(1,1)────────(0,N)►┤ id (PK) │
└─────────┘                   │ created_at                 │                    │ ...     │
                              │ updated_at                 │                    └─────────┘
                              └────────────────────────────┘
```

## Users and practice sessions

```text
                                          ┌───────────────────────────┐
┌───────────────────────┐                 │     practice_sessions     │
│         users         │                 ├───────────────────────────┤                    ┌──────────┐
├───────────────────────┤                 │ id (PK)                   │                    │ problems │
│ id (PK)               ├◄(0,N)─────(1,1)─┤ user_id (FK)              │                    ├──────────┤
│ email                 │                 │ problem_id (FK)           ├─(1,1)────────(0,N)►┤ id (PK)  │
│ password_digest       │                 │ status                    │                    │ ...      │
│ role                  │                 │ review_rating             │                    └──────────┘
│ created_at            │                 │ feedback_summary          │
│ updated_at            │                 │ started_at                │
│ all_problems_unlocked │                 │ completed_at              │
└───────────────────────┘                 │ created_at                │
                                          │ updated_at                │
                                          │ practice_date             │
                                          │ coaching_state            │
                                          │ coach_persona             │
                                          │ review_scheduled_at       │
                                          │ review_base_interval_days │
                                          │ interview_state           │
                                          └───────────────────────────┘
```

## Code attempts

```text
                                        ┌──────────────────────────┐
┌───────────────────┐                   │         attempts         │
│ practice_sessions │                   ├──────────────────────────┤
├───────────────────┤                   │ id (PK)                  │
│ id (PK)           ├◄(0,N)───────(1,1)─┤ practice_session_id (FK) │
│ ...               │                   │ code                     │
└───────────────────┘                   │ language                 │
                                        │ judge_result             │
                                        │ passed_cases             │
                                        │ total_cases              │
                                        │ error_message            │
                                        │ created_at               │
                                        │ updated_at               │
                                        │ judging_started_at       │
                                        └──────────────────────────┘
```

## Coaching and code-review messages

```text
                                        ┌───────────────────────────┐
┌───────────────────┐                   │   conversation_messages   │
│ practice_sessions │                   ├───────────────────────────┤                   ┌──────────┐
├───────────────────┤                   │ id (PK)                   │                   │ attempts │
│ id (PK)           ├◄(0,N)───────(1,1)─┤ practice_session_id (FK)  │                   ├──────────┤
│ ...               │                   │ attempt_id (FK, nullable) ├─(0,1)───────(0,N)►┤ id (PK)  │
└───────────────────┘                   │ role                      │                   │ ...      │
                                        │ content                   │                   └──────────┘
                                        │ created_at                │
                                        │ updated_at                │
                                        │ phase                     │
                                        └───────────────────────────┘
```

A message always belongs to a session, even before any code is submitted.
When `attempt_id` is present, the
[ConversationMessage model](../app/models/conversation_message.rb) validates
that the attempt belongs to the same session.

## Review schedules

```text
                              ┌──────────────────┐
┌─────────┐                   │ review_schedules │
│  users  │                   ├──────────────────┤                      ┌──────────┐
├─────────┤                   │ id (PK)          │                      │ problems │
│ id (PK) ├◄(0,N)───────(1,1)─┤ user_id (FK)     │                      ├──────────┤
│ ...     │                   │ problem_id (FK)  ├─(1,1)──────────(0,N)►┤ id (PK)  │
└─────────┘                   │ next_review_date │                      │ ...      │
                              │ interval_days    │                      └──────────┘
                              │ created_at       │
                              │ updated_at       │
                              │ scheduled_for    │
                              │ reviewed_at      │
                              └──────────────────┘
```

## Background jobs

`delayed_jobs` is the job queue's infrastructure table. It has no database
foreign keys to the learning tables; its `attempts` column counts job retries
and does not reference the `attempts` table.

```text
┌──────────────┐
│ delayed_jobs │
├──────────────┤
│ id (PK)      │
│ priority     │
│ attempts     │
│ handler      │
│ last_error   │
│ run_at       │
│ locked_at    │
│ failed_at    │
│ locked_by    │
│ queue        │
│ created_at   │
│ updated_at   │
└──────────────┘
```
