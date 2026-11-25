# AGENTS.md — faressc-plugins

Guidance for coding agents working on this repo. Claude Code (v2.1.277+, as long as no
`CLAUDE.md` sits here or above) and opencode both read this file natively.

## Skills

Skills live in bucket folders under `plugins/faressc-llm-plugin/skills/`, laid out like
[mattpocock/skills](https://github.com/mattpocock/skills):

- `engineering/`: code work
- `machine/`: driving and administering my own machines
- `productivity/`: non-code workflow tools

Claude Code scans a plugin's `skills/` only one level deep, so a bucketed skill loads only
through its entry in `plugins/faressc-llm-plugin/.claude-plugin/plugin.json`'s `skills`
array. Adding, moving or renaming a skill means updating that array, the bucket's
`README.md` and the top-level `README.md` (skill name linked to its `SKILL.md`), and bumping
the plugin `version`. The opencode bridge in the dotfiles
(`opencode/.config/opencode/plugins/claude-bridge.ts`) reads the same array.

### User-invoked vs model-invoked

Every `SKILL.md` is one of two kinds, split on who can invoke it:

- **User-invoked**: reachable only by the human typing `/name`. Set
  `disable-model-invocation: true`; Claude Code then drops it from the model's skill
  listing and refuses Skill-tool calls to it. The `description` is human-facing: a
  one-line summary for someone browsing slash commands, no trigger lists. Its job is to
  orchestrate.
- **Model-invoked**: reachable by model or user. Omit `disable-model-invocation`. The
  `description` is model-facing and keeps rich trigger phrasing ("Use when the user
  wants…, mentions…") so auto-invocation fires. It holds the reusable discipline. The
  test for staying model-invoked: could the model usefully reach for this on its own?

A user-invoked skill may invoke model-invoked skills, never another user-invoked one.
Write the dependency as an explicit Skill tool call, e.g. `Call the Skill tool with
"grilling"`, not a bare `/grilling` mention and not a link into another skill's folder;
shared reference material lives inside the skill that owns it. One skill per call: a step
that needs two says "call the Skill tool twice, for X and Y". When a precondition is a
user-invoked skill, tell the user to run `/name` instead.

Bucket `README.md`s and the top-level `README.md` group skills under **User-invoked** and
**Model-invoked**.

### GitHub in skills

A skill reaches GitHub only through the GitHub MCP server of the repository's owner
(`github-faressc`, `github-anira`, `github-tanh`), never through `gh`. It names the tools
without the server prefix (`issue_write`, `merge_pull_request`, ...), because the server
differs per repo, and takes the server, the default branch and the local check commands
from the "Agent workflow" section of the repo it works in (template:
`skills/engineering/pr-flow/AGENT-WORKFLOW-SECTION.md`). `pr-flow` is the single place for
the rules of the issue / sub-PR / big-PR workflow; `implement` and `to-tickets` call it
instead of repeating them.

### Vendored skills

Nine skills come from mattpocock/skills (MIT, commit `d6539114`). Each keeps the upstream
`LICENSE` beside its `SKILL.md`, adapted or not; upstream's `agents/openai.yaml` files are
left out.

- Byte-identical to upstream: `productivity/grilling`, `engineering/diagnosing-bugs` (with
  `scripts/hitl-loop.template.sh`) and `engineering/domain-modeling` (with `ADR-FORMAT.md`
  and `GLOSSARY-FORMAT.md`).
- `productivity/grill-me` and `engineering/grill-with-docs` only add the plugin-namespaced
  names Claude Code lists the called skills under.
- `engineering/retro` is adapted: step 1 (calling `writing-for-agents`, which is not
  vendored) is removed and the steps renumbered, the sentence pointing to that skill under
  "Files" is removed, and one parenthesis names `issue-review` as the review agent.
- `engineering/triage` is adapted; `OUT-OF-SCOPE.md` is byte-identical, `AGENT-BRIEF.md` differs in one
  example that named a `gh` command. In `SKILL.md`: `pr-flow` is called first; GitHub is reached
  through the MCP, with the tools named at each step (no `setup-matt-pocock-skills`, no tracker
  config); the role names are the label names, looked up and never created; the state
  `needs-triage` is dropped (an issue without a state role is untriaged) and `needs-tickets` is
  added for a request that needs splitting before it is implemented; an external PR is
  one whose author is not the user; the code of an outside author's PR is not run without asking
  the user; a note for `.out-of-scope/` reaches the repo through a pull request of its own; after
  `ready-for-agent` it names `/implement` or `/to-tickets` as the next step. Upstream's disclaimer
  on every posted comment is kept, as the one exception to `pr-flow`'s rule against attribution
  lines.
- `engineering/to-tickets` is adapted: GitHub issues through the MCP are the only tracker
  (no `setup-matt-pocock-skills`, no local-file variant, no `.scratch`), and `pr-flow` is
  called first for the repo facts and the glossary; the tickets form one linear chain with
  at most one blocker each, and a slice is sized as one sitting to review; the parent issue
  is created first, then the sub-issues in order with `parent_issue_number` (an existing
  issue passed as argument becomes the parent and gets the decisions as a comment); the
  parent carries `ready-for-agent`, and an existing one loses `needs-tickets`; labels are
  looked up, never created; a plan of one slice becomes a standalone issue; no
  prototype-snippet exception.
- `engineering/issue-review` is upstream's `code-review`, renamed to stay clear of Claude
  Code's built-in `/code-review`, and adapted: the fixed point is the pull request's base;
  the spec is the PR's issue, fetched through the MCP; the glossary and the ADRs of the
  area are standards sources; new behaviour without a test is a hard finding on the
  Standards axis; findings carry `path/from/repo/root.ext:123` references and are marked
  hard or judgement call. The smell baseline is upstream's, unchanged.

`engineering/implement` and `engineering/pr-flow` are written here (ideas from upstream's
`implement` and `implement-spec`, no copied text), so they carry no `LICENSE`. The
"Glossary and decisions" section of `pr-flow` is the reading side of `domain-modeling`,
adapted from upstream's `setup-matt-pocock-skills/domain.md`; other skills point to it
instead of repeating it.

To update a vendored skill, copy the upstream files over, re-apply the changes listed
above, and record the new commit here and in the READMEs.

## Checks

After touching a manifest or a skill:

```sh
claude plugin validate . --strict
claude plugin validate plugins/faressc-llm-plugin --strict   # "Provides:" lists the skills that load
```

The plugin-directory findings it prints (no LICENSE, icon or privacy URL) are about
submitting to the public catalog and do not fail the run.

No skill may shell out to `gh`; this finds nothing:

```sh
grep -rn -E '\bgh (pr|issue|api|run|label)\b' plugins/
```
