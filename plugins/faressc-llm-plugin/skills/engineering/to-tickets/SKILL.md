---
name: to-tickets
description: "Break a plan or the current conversation into GitHub issues in order: a parent issue and its sub-issues, published once you approved the split."
disable-model-invocation: true
argument-hint: "[issue number that becomes the parent, optional]"
---

# To Tickets

Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices in one linear chain, published as GitHub issues: a parent issue for the feature and one sub-issue per ticket, in order.

Before anything else, call the Skill tool with "pr-flow" (Claude Code lists it as "faressc-llm-plugin:pr-flow"). Its "Repo facts" say which GitHub MCP server to use (its tools are named below without the server prefix), and its "Glossary and decisions" say what to read before exploring and how to treat it.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments (an issue with `issue_read`: `get`, `get_comments`). An issue passed this way becomes the **parent**.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer the work touches (core, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized so that reviewing its pull request is one sitting
- Any prefactoring should be done first

</vertical-slice-rules>

Order the tickets into one **linear chain**: each ticket is blocked by at most one other, the one before it, and is implemented and merged before the next one starts. The first ticket has no blocker.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket, one after the other in the chain, keeping the build green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, as the last ticket of the chain.

A plan that is one slice is one ticket: a **standalone issue**, without a parent and without sub-issues.

### 4. Quiz the user

Present the proposed breakdown as a numbered list, in chain order. For each ticket, show:

- **Title**: short descriptive name, worded as a request
- **Blocked by**: the ticket before it, or none for the first
- **What it delivers**: the end-to-end behaviour this ticket makes work
- **Labels**: `bug` or `enhancement`, and `ready-for-agent`

Above the list, show the parent: its title and body, or, when the parent is an existing issue, the comment that will carry the decisions.

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Is the order right: does each ticket only need the tickets before it?
- Should any tickets be merged or split further?
- Is any ticket one they implement themselves? It gets `ready-for-human` instead of `ready-for-agent`.

Iterate until the user approves the breakdown. Nothing is created on GitHub before that.

### 5. Publish the issues

Publish the approved breakdown with `issue_write` (`method: "create"`), in this order:

1. **Labels.** Look up every label you are about to use with `get_label`; do not create labels. If a ticket is to carry `ready-for-human` and the repo has no such label, ask the user before publishing anything: that label is what stops `/implement` from taking the issue. Leave off any other label the repo does not have and name it in your final message.
2. **The parent.** Its title names the feature as a request, its body follows the parent template below, its label is `bug` or `enhancement`. Do NOT close or modify an existing parent issue: post the decisions as one comment on it with `add_issue_comment`.
3. **The sub-issues**, in chain order (blockers first), so each "Blocked by" can reference a real issue number. Create each with `parent_issue_number` set to the parent, its labels, and the body from the issue template below. If the order under the parent comes out wrong (`issue_read`, `get_sub_issues`), correct it with `sub_issue_write` (`reprioritize`). It works with issue IDs, not issue numbers: `sub_issue_id`, `after_id` and `before_id` are the `id` fields that `issue_read` (`get`, `get_sub_issues`) returns.

A standalone issue is one `issue_write` call without `parent_issue_number` and without the "Blocked by" section. If the user passed an existing issue and the plan is one ticket, create nothing: that issue is the standalone issue.

<parent-template>

## Outcome

What works once the whole feature is merged, from the user's perspective.

## Decisions

- Each decision the plan or the grilling settled, one line each.

</parent-template>

<issue-template>

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

`Blocked by #<issue number>` for the ticket before it in the chain, or "None (can start immediately)".

</issue-template>

Avoid specific file paths or code snippets in issue bodies: they go stale fast. Issue bodies and comments carry no attribution lines.

Finish with the list of what was created (number, title, labels), every label that was missing, and the next step for the user to type: `/implement <number of the last sub-issue>`.
