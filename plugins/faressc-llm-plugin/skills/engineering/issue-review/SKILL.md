---
name: issue-review
description: "Review one pull request's diff against its base along two axes: Standards (does the code follow this repo's documented coding standards, and does new behaviour come with a test?) and Spec (does the code do what its issue asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when a sub-PR or a standalone issue's PR is ready for review, before a sub-PR is merged, or when the user wants a PR or a branch reviewed against its issue."
---

Two-axis review of one pull request, the diff between its head and its base:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the issue it was written for?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings. Start every sub-agent with a fresh context window.

GitHub is read through the MCP server of the repository's owner. The "Agent workflow" section of the repo's `AGENTS.md` names it; without that section it is the server named after the owner of `origin`. Its tools are named below without the server prefix.

## Process

### 1. Pin the fixed point

The fixed point is the pull request's base: the feature branch for a sub-PR, the default branch for a standalone issue's PR. Read it with `pull_request_read` (`get`), then `git fetch origin`. Without a pull request, whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff origin/<base>...<head>` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log origin/<base>..<head> --oneline`. `<head>` is `origin/<head branch>` after the fetch, or `HEAD` when that branch is checked out at the pushed commit. For a sub-PR that is already merged, both come from its merge commit, the PR's `merge_commit_sha`: `git diff <merge>^1 <merge>` and `git log <merge>^1..<merge>^2 --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

### 2. Fetch the spec

The spec is the issue the pull request implements. Look for its number, in this order:

1. The pull request's body: `Implements #41 (part of #40)` on a sub-PR, `Closes #41` on a standalone issue's PR.
2. Issue references in the commit messages (`#123`).
3. An issue number the user passed as an argument.
4. If nothing is found, ask the user which issue it is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

Fetch the issue's body and comments with `issue_read` (`get`, `get_comments`). For a sub-issue, fetch the parent's body and comments too (`get_parent`, then `get_comments` on the parent): they carry the decisions of the feature.

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list, and so must the glossary and the ADRs of the area the diff touches (`GLOSSARY.md`, `docs/adr/`, or where the "Agent workflow" section says they live); where they do not exist, go on without them.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

Issue both sub-agent calls together, in the foreground, and aggregate the reports they return.

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell you spot: name it and quote the hunk; and (c) every new or changed behaviour in the diff that no test in the repo's test suite exercises, and every bug fix without a test that fails without the fix: name the behaviour. Distinguish hard violations from judgement calls: documented-standard breaches and missing tests are hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Reference code as `path/from/repo/root.ext:123`, always with the full path from the repository root. Under 400 words."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The fetched contents of the issue, and of its parent (body and comments) where it has one.
- The brief: "Report: (a) requirements and acceptance criteria the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. (a) and (c) are hard findings, (b) is a judgement call. Quote the spec line for each finding, and reference code as `path/from/repo/root.ext:123`, always with the full path from the repository root. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, how many of them are hard, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
