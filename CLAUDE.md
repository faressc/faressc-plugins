# faressc-plugins

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

### Vendored skills

`productivity/grill-me` and `productivity/grilling` come from mattpocock/skills (MIT,
commit `d6539114`). Each keeps the upstream `LICENSE` beside its `SKILL.md`. `grilling`
is byte-identical to upstream; `grill-me` only adds the plugin-namespaced name Claude Code
lists `grilling` under. To update, copy the upstream files over, re-apply that one
change, and record the new commit here and in the READMEs.

## Checks

After touching a manifest or a skill:

```sh
claude plugin validate . --strict
claude plugin validate plugins/faressc-llm-plugin --strict   # "Provides:" lists the skills that load
```

The plugin-directory findings it prints (no LICENSE, icon or privacy URL) are about
submitting to the public catalog and do not fail the run.
