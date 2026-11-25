# Engineering

Daily code work.

## User-invoked

Reachable only when you type them (`disable-model-invocation: true`).

- **[grill-with-docs](./grill-with-docs/SKILL.md)**: the `grill-me` interview, which also writes the glossary and ADRs as it goes. Hands off to `grilling` and `domain-modeling`.
- **[to-tickets](./to-tickets/SKILL.md)**: break a plan into GitHub issues in order, a parent issue and its sub-issues, published once you approved the split.
- **[implement](./implement/SKILL.md)**: implement a feature's issues in order, up to and including the one you name, each as a reviewed and merged sub-PR into the feature branch; or one standalone issue as a draft PR. Follows `pr-flow`, reviews with `issue-review`, takes bugs through `diagnosing-bugs`.
- **[explain-pr](./explain-pr/SKILL.md)**: explain what the current branch or PR changes, in plain language and in execution order, with code references.
- **[retro](./retro/SKILL.md)**: a retrospective on a coding session: candidates for improving the agent's environment (navigation, automated checks, coding standards, steering files), presented to you; it edits nothing by itself.

## Model-invoked

Model- or user-reachable (rich trigger phrasing so the model can reach for them).

- **[pr-flow](./pr-flow/SKILL.md)**: the rules for issue and pull-request work: feature branch, sub-PRs, the big PR and its ledger, commits, tests, the CI decision, what an agent may merge, and the glossary and ADRs to read first. Repo facts come from the "Agent workflow" section of the repo's `AGENTS.md`.
- **[issue-review](./issue-review/SKILL.md)**: review one pull request against its base in two parallel sub-agents, one for the repo's standards (and missing tests), one for the issue it implements; the two reports stay separate.
- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)**: diagnosis loop for hard bugs and performance regressions: no fix before one command reproduces the bug.
- **[domain-modeling](./domain-modeling/SKILL.md)**: build and sharpen the project's domain model: challenge terms, and write `GLOSSARY.md` and ADRs (`docs/adr/`) the moment a term or a decision is settled.

The flow: `/grill-me` or `/grill-with-docs`, then `/to-tickets`, then `/implement <issue number>`, then review on the feature branch with `/explain-pr <sub-PR number>`, and `/retro` after a run.

All of these except `explain-pr`, `implement` and `pr-flow` come from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT, commit `d6539114`); each keeps the upstream `LICENSE` beside its `SKILL.md`. `diagnosing-bugs` and `domain-modeling` are unchanged; `grill-with-docs` only adds the plugin-namespaced skill names; `to-tickets`, `issue-review` (upstream `code-review`) and `retro` are adapted, the changes are listed in the repo's `AGENTS.md`. None of the skills here calls `gh`.
