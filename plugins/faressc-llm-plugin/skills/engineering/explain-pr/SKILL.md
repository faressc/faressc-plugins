---
name: explain-pr
description: Explain what the current branch or PR changes, in plain language and in execution order, with code references.
disable-model-invocation: true
argument-hint: "[PR number or base branch, optional]"
---

Explain the changes on this branch (or PR $ARGUMENTS if given) so I fully understand what they do.

## Gather context

- If a PR number is given (a sub-PR's number works the same): read the PR and its base with `pull_request_read` (`get`) on the GitHub MCP server of the repository's owner, `git fetch origin`, and use `git log --oneline origin/<base>..origin/<head>` and `git diff origin/<base>...origin/<head>`. For a sub-PR that is already merged, use its merge commit instead (its `merge_commit_sha` from `pull_request_read`): `git log --oneline <merge>^1..<merge>^2` and `git diff <merge>^1 <merge>`.
- Otherwise find the base (`list_pull_requests` filtered by `head`, written `<owner>:<branch>`, for the current branch, else main/master), `git fetch origin`, and use `git log --oneline origin/<base>..HEAD` and `git diff origin/<base>...HEAD`.
- Read the full changed files and the callers/callees you need, not only the diff hunks.

## Output, in this order

1. **What it brings, in simple terms.** Two or three short paragraphs: the problem, what now works differently, and why it matters. No jargon unless defined. If it makes the change easier to grasp, include a small example of the new behaviour (e.g. a command, a config snippet, or what the user now sees).
2. **Execution-order walkthrough.** Start at the real entry point (main, callback, CLI command, request handler, audio callback, etc.) and follow the code path as it actually runs, not file by file. For each step:
   - reference the code as `path/to/file.cpp:123` (or a line range, `path/to/file.cpp:123-140`), always with the full path from the repository root, also for a file already named: never the bare file name (`file.cpp:123`) or a bare line (`:123`), so every reference opens on its own
   - say what this step does and what changed compared to before
   - point out threading, lifetime, real-time or error-handling implications
   - where it helps, add a concrete example: sample input and the resulting output or state, a before/after of the behaviour, or a short usage snippet of a new API. Skip it when the step is already obvious.
3. **Things outside the main path.** Config, build system, tests, docs, and refactors that don't change behaviour.
4. **Risks and open questions.** Anything that looks suspicious, untested, or inconsistent with the PR description or commit messages.
5. **Diffview command.** End with the command that opens exactly what you explained: `:DiffviewOpen <merge>^1..<merge>` for a merged sub-PR, otherwise `:DiffviewOpen origin/<base>...HEAD` (`origin/<base>...origin/<head>` when the PR's branch is not checked out), with the real names and SHAs filled in.

Be detailed. Read the code before explaining it and never guess what a function does.
