# Contributing

## Pull requests and commit messages

Use the [PR template](.github/pull_request_template.md) to explain why the
change is needed, how it works, its data flow, and the exact validation
commands and results.

Commit messages need a capitalized, imperative subject of at most 50
characters with no final period, followed by a blank line and a body wrapped
at 72 characters. Explain what changed, why, and the change type (such as a
fix, feature, or documentation update).

The `Commit and PR messages` CI check enforces subject formatting, commit
body formatting, and filled-in PR sections. It runs when PRs are opened,
edited, or updated with commits. It checks structure; authors remain
responsible for accurate explanations and imperative wording.

To block merges on failures, select `Commit and PR messages` as a required
status check in the repository's branch rules after its first run.

To show the [commit template](.gitmessage) in your editor, optionally run
this once per clone from the repository root:

```sh
git config --local commit.template .gitmessage
```

The template provides reminders; it does not validate messages. Messages
supplied with `-m` or `-F` bypass it. Git's default editor cleanup removes
its comment lines. To disable it:

```sh
git config --local --unset commit.template
```
