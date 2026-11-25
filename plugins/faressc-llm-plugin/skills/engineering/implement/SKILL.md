---
name: implement
description: Implement a feature's issues in order, up to and including the given one, each as a reviewed and merged sub-PR; or a single standalone issue as a draft PR.
disable-model-invocation: true
argument-hint: "<issue number: implement up to and including this one>"
---

Implement the issues in order, up to and including issue $ARGUMENTS. Without an issue number, ask for one first.

Before anything else, call the Skill tool with "pr-flow" (Claude Code lists it as "faressc-llm-plugin:pr-flow"). It holds the rules the steps below rely on: repo facts, the glossary and decision records to read first, when an issue is done, branch names, commits and tests, PR bodies, the ledger, merging, CI and the review commands.

## 1. Read the issue and pick the mode

Fetch the issue with `issue_read` (`get`) and state its title.

- It has a parent (`get_parent`): **feature mode**. The parent's sub-issues (`get_sub_issues`), in their order, are the chain, and the run ends with the given issue.
- It has sub-issues itself: it is the parent. **Feature mode**, and the run covers the whole chain.
- Neither: **standalone mode**, the last section.

## 2. Find where to go on (feature mode)

Reconcile with GitHub first. The user may have merged a sub-PR or implemented an issue themselves since the last run, so the ledger alone is not the state.

1. **Parent.** Read its body and comments (`get_comments`): the decisions of the feature, and the `Feature branch:` comments. The newest of those names the current feature branch. If there is none, nothing has started: create the feature branch, post the `Feature branch: feat/<slug>` comment on the parent with `add_issue_comment` (nothing else in it), and go to the work list.
2. **Sub-PRs.** `list_pull_requests` with `base` the feature branch and `state: "all"`. The first line of each body names its issue (`Implements #41 (part of #40).`). A merged one makes its issue done. An open one is where an earlier run stopped: when its issue comes up, `git fetch origin`, switch to its branch, and go on from the step it stopped at (review, CI or merge) instead of creating the branch again.
3. **Big PR.** `list_pull_requests` with `head` `<owner>:<feature branch>` and `state: "all"`.
   - Open: its body is the ledger. Bring it in line with what you found: tick what is done but not ticked, and correct its first line.
   - None, although sub-PRs are merged: open it now.
   - Merged or closed while issues of the chain are not done: the rest is a new round on a new feature branch, `feat/<slug>-round-2` (counting up), created like the first one, with its own `Feature branch:` comment and, after its first merge, its own big PR and ledger. Never reuse a feature branch's name: a feature branch has exactly one big PR, which is how a later run tells the rounds apart.

The work list is the chain's issues that are not done, from the first one up to and including the given issue, or to the end of the chain when the parent was given. State it, numbers and titles, before you start. If it is empty, say so and stop.

## 3. One issue at a time

Take the work list in order. Finish all nine steps for one issue before the next one starts.

1. **Check that it is yours.** Stop the run at an issue labelled `ready-for-human`, or at one whose `Blocked by #N` names an issue that is not done. Only issues that are not done are in the work list, so one the user has finished never stops the run.
2. **Read it**: body and comments. The acceptance criteria are what the sub-PR has to meet.
3. **Branch** from the tip of the feature branch.
4. **Implement** the issue the way you normally would, with tests for the new code and one commit per specific change. An issue labelled `bug` always gets a test that fails without the fix. When its cause is not evident from the report, or the bug does not reproduce at the first attempt, call the Skill tool with "diagnosing-bugs" (Claude Code lists it as "faressc-llm-plugin:diagnosing-bugs") before changing code.
5. **Run the local checks**, push, and open the sub-PR.
6. **Review.** Call the Skill tool with "issue-review" (Claude Code lists it as "faressc-llm-plugin:issue-review") on the sub-PR. If it reports hard findings, fix them as new commits, run the checks, push, and call it once more. If the second review still reports hard findings, stop the run. A judgement call you leave as it is becomes an open review note in the ledger, with the reason.
7. **Decide about CI**: wait for the sub-PR's runs, or go on. When you wait and three rounds of fixes have not made them pass, stop the run.
8. **Merge** the sub-PR into the feature branch, and only a PR whose base is that branch. If the merge is denied, stop the run: the user merges it.
9. **Update the big PR**: open it after the first merge; afterwards rewrite the ledger (tick the entry with its sub-PR and merge commit, correct the first line, add the open review notes).

A run that stops early leaves that sub-PR open and unmerged, and goes on with section 4 for what is merged.

## 4. Follow the last runs

After the last merge, follow the big PR's CI runs for that push. Fix failures as follow-up commits on the feature branch, each naming its issue, and list them in the ledger. After three rounds of fixes without a passing push, stop and report the failing job.

## 5. Report

- **Merged**: one line per issue with its sub-PR and merge commit.
- **Open**: the issue the run stopped at and why, and the issues not started.
- **CI**: per push whether its runs passed, failed (and what you fixed), are still running, or never started.
- **Assumed**: what you took from the repo instead of an "Agent workflow" section, with the proposed section.
- **Review**: the line that puts the user on the feature branch, and the four review commands from pr-flow with this repo's default branch and this run's merge commits filled in.
- **Next**, for the user to type: `/explain-pr <sub-PR number>` for a walkthrough of one sub-PR, `/implement <issue number>` to go on.

## Standalone mode

One issue, one draft PR against the default branch, which you never merge and never mark ready:

1. Read the issue and its comments. Stop if it is labelled `ready-for-human`.
2. Branch from `origin/<default>`, implement as in step 4 above, run the local checks, push, and open the draft PR with `Closes #N`.
3. Review as in step 6 above; the fixed point is the default branch.
4. Follow the PR's CI runs and fix failures as new commits, three rounds at most.
5. Report as above. The review command is `:DiffviewOpen origin/<default>...HEAD`.
