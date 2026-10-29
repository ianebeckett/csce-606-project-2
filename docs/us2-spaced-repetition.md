# Spaced repetition model contract

Spaced repetition uses the existing practice-session records and review schedules. A completed 
practice session stores a performance rating (`review_rating`) from 1 to 5. Each review schedule 
belongs to a user and problem and stores the review interval and next review date.

The `ReviewScheduler` service calculates the next review date using the student's rating. 
Ratings 1 and 2 reset the interval to 1 and 2 days, rating 3 keeps the current interval, 
rating 4 doubles it, and rating 5 triples it. New schedules begin with a one-day interval.

Each user and problem has one unique review schedule. The `review_scheduled_at` field prevents 
the same completed practice session from updating the schedule multiple times.

Due reviews are problems with review dates on or before the current date. Queries are scoped to 
the logged-in learner, and due reviews appear alongside unlocked problems on the dashboard. 
Learners without due reviews see an appropriate empty-state message.

After a coding attempt is evaluated, students rate their understanding of the problem on 
a scale of 1–5. The rating is saved when the practice session is completed and used to 
calculate the next review date.
