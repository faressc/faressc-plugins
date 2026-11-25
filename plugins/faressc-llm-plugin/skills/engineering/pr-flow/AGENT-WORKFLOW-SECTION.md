# The "Agent workflow" section of a repo's `AGENTS.md`

For a repo that has no such section: fill this in from what you found in the repo and put it into your report as a proposal. Write it into the repo's `AGENTS.md` only when the user asks for that.

```markdown
## Agent workflow

- **GitHub**: MCP server `github-<owner>`, repository `<owner>/<repo>`, default branch `<branch>`.
- **Local checks, before every push**:
  - build: `<command>`
  - tests: `<command>`
  - format and lint: `<command>`
- **Not testable locally**: <other operating systems, mobile, wasm, backends missing on this machine, or "nothing">. A change there waits for the sub-PR's CI run.
- **Standards and decisions**: <`CODING_STANDARDS.md` or `CONTRIBUTING.md`; the glossary and the ADRs only if they are not at `GLOSSARY.md` and `docs/adr/`; or "none yet">.
- Issues, branches, pull requests, commits and CI follow the `pr-flow` skill.
```

Mark every value you guessed rather than read from a file, so the user can correct it.
