# User Guide

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
