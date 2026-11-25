---
name: pr-flow
description: "Rules for issue and pull-request work: the feature branch, sub-PRs, the big PR and its ledger, commits, tests, the CI decision, and what an agent may merge. Use when implementing a GitHub issue, opening, updating or merging a pull request, pushing to a feature branch, deciding whether to wait for CI, or changing code after a PR review."
---

# PR flow

The rules for working on an issue, in any session, whether `/implement` started it or not.

## The model

| Thing | On GitHub | Who merges |
|---|---|---|
| Feature | a parent issue, a feature branch, and one **big PR** against the default branch | the user |
| Issue | a sub-issue of the parent, and one **sub-PR** into the feature branch | you, with a merge commit |
| Standalone issue (no parent, no sub-issues) | one draft PR against the default branch | the user |

Sub-PRs are sequential: one is merged before the next one starts, and the next branch starts from the feature branch's new tip.

An issue is **done** when it is closed on GitHub, or ticked in the ledger, or named by a merged sub-PR into the feature branch.

**You merge sub-PRs into a feature branch, and nothing else.** A default or protected branch only ever gets a pull request from you: no push to it, no merge into it, and a PR against it stays a draft until the user marks it ready.

## Repo facts

Read the "Agent workflow" section of the repo's `AGENTS.md`: the GitHub MCP server of the repository's owner, the default branch, the local check commands, what cannot be tested locally, and where standards and decisions live.

If the section is missing, go on without it. Derive the facts from the repo, say in your report what you assumed, and propose the section there, filled in from [`AGENT-WORKFLOW-SECTION.md`](AGENT-WORKFLOW-SECTION.md):

- the server is the one named after the owner of `origin`: `github-faressc`, `github-anira`, `github-tanh`;
- the default branch: `git symbolic-ref --short refs/remotes/origin/HEAD` prints `origin/<name>`, and the default branch is the part after `origin/`. If it is unset, run `git remote set-head origin -a` first;
- the local checks and what they cannot cover: `README`, `CMakePresets.json` or `pyproject.toml`, `.github/workflows/`.

All GitHub access goes through that server's tools, named below without the server prefix. A 404 on a repository means the wrong owner's server.

## Glossary and decisions

Before exploring code for an issue, read `GLOSSARY.md` at the repo root (or `GLOSSARY-MAP.md`, which points at one glossary per context) and the ADRs in `docs/adr/` that touch the area, unless the "Agent workflow" section names other locations. Where they do not exist, proceed silently: do not flag their absence and do not create them. The "domain-modeling" skill creates them lazily, when a term or a decision is actually settled.

- Use the glossary's terms in issue titles, PR text, test names and reports.
- If a change contradicts an ADR, say so explicitly ("Contradicts ADR-0007, but worth reopening because ...") instead of silently overriding it.

## Branches

- **Feature branch**: `feat/<slug>`, with a short kebab-case slug from the parent issue's title. Create it when the first sub-issue starts, on the remote, from the default branch's tip: `git fetch origin`, then `git push origin origin/<default>:refs/heads/feat/<slug>`. Then post one comment on the parent issue with `add_issue_comment` that holds only `Feature branch: feat/<slug>`. A later session takes the branch from the parent's comments (`issue_read`, `get_comments`): the newest such comment names the current one, and none means nothing has started.
- **Sub-PR branch**: `feat/<slug>-<issue number>`, from the feature branch's tip: `git fetch origin`, then `git switch -c feat/<slug>-<issue number> --no-track origin/feat/<slug>`.
- **Standalone issue**: `fix/<slug>` for a `bug`, otherwise `feat/<slug>`, from the default branch's tip: `git fetch origin`, then `git switch -c <branch> --no-track origin/<default>`.
- **Pushing**: always by name, `git push -u origin <branch>`. `--no-track` above keeps a bare `git push` from ever targeting the branch a new one started from.

## Commits and tests

- A commit is one specific code change, with a message in the repo's own style (read `git log`).
- History only grows. A CI fix or a change after a review is a new commit: no amending or rebasing what is pushed, no squash or fixup, no force-push.
- Commit messages, PR bodies, issue bodies and comments carry no attribution lines (`Co-Authored-By`, "Generated with ...").
- New code comes with tests in the repo's existing test suite. A bug fix gets a test that fails without the fix.
- Run the repo's local checks before every push. Name a check that could not run in the PR body.

## Sub-PR

Open it with `create_pull_request`: `base` the feature branch, `head` the sub-PR branch, `draft: false` (a draft cannot be merged), the issue's title as title. `Closes #N` has no effect on a PR against a non-default branch, so the body reads:

```markdown
Implements #41 (part of #40).

<what changed, in two or three sentences>

Checked locally: <commands run and their results>.
Not checked locally: <what and why, or "nothing">.
```

Before the merge, call the Skill tool with "issue-review" (Claude Code lists it as "faressc-llm-plugin:issue-review") and fix its hard findings as new commits.

Merge with `merge_pull_request`: `merge_method: "merge"`, `expectedHeadSha` the commit you pushed last (`git rev-parse HEAD`), `commit_title` `<issue title> (#<issue>, sub-PR #<PR>)`. Read the PR back with `pull_request_read` (`get`) first and merge only when its base is the feature branch. Afterwards `git fetch origin`; the merge commit is the PR's `merge_commit_sha` (`pull_request_read`, `get`). If the merge is denied, leave the sub-PR open and report it as ready to merge.

## Big PR and ledger

Open the big PR right after the first sub-PR is merged (before that the feature branch has nothing ahead of the default branch): `create_pull_request` with `base` the default branch, `head` the feature branch, `draft: true`, the parent issue's title as title.

Its body is the ledger of the feature. Rewrite it with `update_pull_request` after every sub-PR merge, every follow-up commit, and every review note that stays open:

```markdown
Part of #40. Closes #41, closes #42.

## Sub-PRs, in order
- [x] #41 Save and restore a preset: sub-PR #45, merge 15372c8
- [x] #42 Preset browser: sub-PR #46, merge 51da992
- [ ] #43 Factory presets

## Follow-up commits on this branch
- 783794b Fix CI: missing include on macOS (#41)

## Open review notes
- #42: the browser reloads the whole list on every change; accepted for now.
```

- The list holds every sub-issue of the parent, in order. Tick an issue when it is done: with its sub-PR and merge commit, or with `closed` when it was closed without one.
- The first line closes every ticked sub-issue that is still open on GitHub.
- The parent goes on the first line only when every sub-issue is done; landing the big PR earlier must not close it. Until then the line starts with `Part of #40.`; with the last tick it becomes `Closes #40, closes #41, closes #42, closes #43.`

## Standalone issue

One PR: `create_pull_request` with `base` the default branch and `draft: true`. Its body starts with `Closes #N.` and continues like a sub-PR's. Have it reviewed with "issue-review" as above. It stays a draft, and the user merges it.

## CI

CI runs on every push and is not a condition for merging a sub-PR. Decide per sub-PR:

- **Wait** for the sub-PR's runs when the change touches something the repo lists as not testable locally (other operating systems, mobile, wasm, a backend missing on this machine), or when a local check could not run. Fix failures as new commits on the sub-PR.
- **Go on** when the local build and tests cover the change: merge, and let the big PR's runs on the merged state be the check.

The gate is the big PR's runs (for a standalone issue, its PR's runs). Before you finish, follow them for your last push and fix failures as follow-up commits on the feature branch.

- The runs of a push are the workflow runs whose `head_sha` is the commit you pushed, across all workflows: `actions_list` with `list_workflow_runs` filtered by the branch, then `list_workflow_jobs`. The push passed when all of them completed successfully. The log of a failed job comes from `get_job_logs`.
- If about two minutes after the push no run with that SHA exists, the repo's CI does not run for this pull request: say so in your report and go on. For a sub-PR the big PR's runs are then the check.
- Watch runs the way the user's global instructions prescribe for watching PR checks.

## Commits on the feature branch itself

A fix for a failure of the big PR's runs and a change the user asks for after their review are committed directly on the feature branch, without a sub-PR:

1. `git fetch origin`, then work at the feature branch's tip: `git switch <feature branch>` and `git merge --ff-only origin/<feature branch>`. If git refuses because the branch is checked out in another worktree, use `git switch --detach origin/<feature branch>` and push with `git push origin HEAD:<feature branch>`.
2. One commit per specific change, each message naming the issue it belongs to (`(#41)`). Run the local checks and push.
3. Add the commits to the ledger's follow-up list, and report the range `<before>..<after>` so that only the new commits need a look.

## Reporting

Wherever you tell the user what to review, print first the line that puts them on the feature branch at its newest state:

```sh
git fetch origin && git switch <feature branch> && git merge --ff-only origin/<feature branch>
```

Then the matching commands for nvim, with the repo's default branch in place of `main` and the real SHAs filled in:

- every sub-PR as one entry, oldest first: `:DiffviewFileHistory --range=origin/main..HEAD --first-parent --diff-merges=first-parent --reverse`
- one sub-PR: `:DiffviewOpen <merge>^1..<merge>`
- the whole feature: `:DiffviewOpen origin/main...HEAD`
- new commits after a refinement: `:DiffviewOpen <before>..<after>`

Reference code as `path/from/repo/root.ext:123`, always with the full path from the repository root.
