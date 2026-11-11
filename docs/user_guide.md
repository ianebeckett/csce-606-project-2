# User Guide

Create an account or sign in, then open **Roadmap & Practice**. Free and Premium
members have the same access to the roadmap and Ruby judge. These pages work
with JavaScript disabled.

## Choose a problem

The roadmap shows each topic's prerequisites and your current state:

- **Locked:** At least one prerequisite has not been mastered. Complete its
  problems first; direct links and submissions cannot bypass the lock.
- **In Progress:** The topic is unlocked and still has unsolved problems. An
  unlocked topic with no problems also stays In Progress.
- **Mastered:** Every problem in the unlocked topic has an Accepted submission
  from your account. Empty topics are never mastered.

Select an unlocked topic to see its curated problems, difficulty, and completion
status. **Not solved** means you have no Accepted submission for that problem.
**Accepted** means you have completed it; later unsuccessful retries do not
erase that completion. Another member's work never changes your progress.

Start with **Arrays & Hashing**. Mastering it unlocks **Two Pointers**, **Stack**,
**Binary Search**, and **Linked List**. Master **Two Pointers** to unlock
**Sliding Window**. Empty topics explain that no problems are available yet.

## Practice and review a submission

Open a problem, read its statement and examples, and complete the supplied Ruby
method. Select **Submit Ruby solution** to run the predefined cases. The result
shows the verdict, passed-case count, and your saved source code. A problem must
have at least five cases before it can be judged.

An Accepted solution updates your roadmap immediately. Wrong Answer,
Compilation Error, Runtime Error, and Timeout leave the problem unsolved unless
you previously solved it. If the judge is unavailable, your submitted code is
saved so you can retry later.

Use **My submissions** to revisit your own attempts. **Try this problem again**
restores your latest submitted code. Sign out when finished.

## AI code review (Premium)

After you submit a solution, Premium members can ask an AI reviewer for feedback on it. The review covers correctness, time and space complexity, missed edge cases, and code style problems.

### Getting a review

1. Submit a solution to any problem.
2. On the submission page, click **Get AI code review**.
3. The review page shows:
   - a **Summary** of how your solution does, with its time and space complexity;
   - **your code with line numbers**, with each suggestion placed directly under the lines it refers to;
   - **General suggestions** that apply to the whole solution, if there are any.

Each suggestion is labeled with its type (Correctness, Complexity, Edge case, or Anti-pattern) and the lines it refers to.

![AI code review of a Contains Duplicate solution, with a complexity suggestion under the nested loop](images/ai-code-review.png)

A correct and efficient solution may get no specific suggestions. AI feedback can be wrong, so treat it as a starting point rather than a final verdict.

### If the review is unavailable

If the AI service is down or sends back something the app can't use, you'll see "AI code review is unavailable right now." Your submitted code is saved, so you can try again later.

### Free members

Free members see "AI code review is available to Premium members." on the submission page instead of the review button. Everything else, including submitting solutions and seeing judge results, works the same.

![A Free member's submission page, showing the Premium notice instead of the review button](images/ai-code-review-free-member.png)

## Interview mode (Premium)

Interview mode lets Premium members rehearse a real coding interview. You start from a deliberately vague problem, ask clarifying questions, explain a plan, and adapt when the interviewer changes a requirement.

### Starting an interview

1. Open any problem that has interview content.
2. Click **Practice as an interview**.
3. The interview page shows the vague statement, your conversation with the interviewer, a message box, and a note that the editor is locked.

Leaving and coming back the same day resumes the same interview.

### The three stages

1. **Clarify.** Ask questions about the problem. The interviewer answers only what you ask. Once you have asked about enough of the missing details, the interviewer asks for your plan, and the page lists what you have learned so far.
2. **Strategy.** Describe your approach. When the interviewer judges it sound for the requirements, it posts a changed requirement, and the page then shows the full problem statement and examples.
3. **Twist.** Explain how you would adapt your solution. When the interviewer is satisfied, the editor unlocks.

The interviewer never writes code for you, and it does not hand out details you have not asked about.

![An interview for Contains Duplicate at the twist stage: the interviewer has changed the list size, the full problem is shown, and the editor is still locked](images/interview-mode.png)

### Coding

Once the editor is unlocked, submit your solution on the interview page. The usual judge runs it against the problem's tests, and the result page is the same as for any other submission. Finishing the interview also unlocks the editor on the normal problem page for that day.

### If the interviewer is unavailable

If the AI service is down or sends back something the app can't use, you'll see "The interviewer is unavailable right now. Your message is saved, and the editor is unlocked." Your message stays in the conversation and you can start coding right away.

### Free members

Free members who try to open an interview are sent back to the problem page with "The interviewer is a Premium feature." Everything else works the same.
