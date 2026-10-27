# Learning history model contract

Learning history uses the existing practice-session and attempt records. A
conversation message belongs to an attempt and stores a `user` or `assistant`
role with its content. A review schedule belongs to a user and problem, stores
the scheduled date, and may store when the review was completed.

All learner queries start from the learner's associations. Solved problems are
distinct problems with at least one Accepted attempt; review count is the
learner's number of review schedules. Topic progress reports solved and total
problem counts for each topic.

These message and review-schedule associations are provisional local contracts
for development. Confirm their compatibility with the upstream US2, US3, US4,
and US7 interfaces before real integration.
