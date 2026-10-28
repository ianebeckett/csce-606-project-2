# Learning history model contract

Learning history uses the existing practice-session and attempt records. A
conversation message (from US4) belongs to a practice session, and optionally
to one of its attempts. The history detail page shows the messages of the
attempt's practice session. A review schedule belongs to a user and problem,
stores the scheduled date, and may store when the review was completed.

All learner queries start from the learner's associations. Solved problems are
distinct problems with at least one Accepted attempt; review count is the
learner's number of review schedules. Topic progress reports solved and total
problem counts for each topic.

The review-schedule table is a provisional local contract for development.
Confirm its compatibility with the upstream interfaces before real integration.
