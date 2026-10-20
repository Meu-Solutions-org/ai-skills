---
name: feature-workflow
description: Full feature development pipeline — plan → review → implement → code review → QA → merge request. Invoke with a feature description or a Plane ticket ID (`FOSCO-18`, any project in `references/projects.json`).
argument-hint: '<feature description | PROJECT-n> [--base <branch>]'
---

You are the orchestrator of a multi-agent feature development pipeline. Follow these phases strictly and in order.

**Agents.** The phases delegate to the `backend-engineer`, `code-reviewer` and `qa-qc` agents when the
current tool and repo provide them (Claude Code with those agents defined). If an agent is not available
(e.g. in Codex or ChatGPT, or a repo without them), do that phase yourself in the same role and produce
the same output and verdict. The approval gate after Phase 1 applies either way.

## Pipeline

```
User prompt → [BEE: Plan] → User approves → [BEE: Implement] → [Reviewer: Code Review] → [QA: Test] → Merge Request
```

---

## Phase 0 — Input (only when a ticket ID is given)

If the input contains a `<PROJECT>-<n>` ticket ID, resolve the project with
`references/resolve-project.md` (in this skill's folder), then run the
`plane-ticket-summarizer` skill on it. Use its summary (plus any extra text from the user) as the
feature description for Phase 1. If the summary flags an unplanned parent or missing design context,
surface that to the user before planning. Otherwise skip this phase and use the user's description as is.

---

## Phase 1 — Planning

Delegate to the `backend-engineer` agent:

> "Create an implementation plan for the following feature. Do not write any code yet.\n\n<user prompt>"

Present the full plan to the user and ask:

> "Here is the implementation plan. Please review it and reply **'implement'** when ready, or provide feedback to revise."

**Wait for user approval before proceeding.** Do not move to Phase 2 unless the user explicitly approves.

---

## Phase 2 — Implementation

Once the user approves, delegate to the `backend-engineer` agent:

> "Implement the following approved plan exactly as described. Do not add features beyond the plan scope.\n\n<approved plan>"

Collect the implementation summary from the agent.

---

## Phase 3 — Code Review

Delegate to the `code-reviewer` agent:

> "Review the code changes made for this feature. Here is what was implemented:\n\n<implementation summary>"

- If verdict is **APPROVED**: proceed to Phase 4
- If verdict is **CHANGES REQUESTED**: delegate fixes back to `backend-engineer`, then re-run code review
- If verdict is **BLOCKED**: stop, report the critical issues to the user, and wait for instructions

---

## Phase 4 — QA Testing

Delegate to the `qa-qc` agent:

> "Test the following feature. Here is the implementation summary and the code review result:\n\n<implementation summary>\n\n<code review result>"

- If verdict is **PASSED**: proceed to Phase 5
- If verdict is **FAILED** due to an implementation bug: delegate the fix to `backend-engineer`, re-run code review, then re-run QA
- If verdict is **FAILED** due to environment issues: report to user and wait for instructions

---

## Phase 5 — Merge Request

Pick the base branch, first match wins:
1. `--base <branch>` given by the user.
2. `base_branch` of the project profile, when Phase 0 resolved a Plane project.
3. The repo's default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).

Use the `commit` skill and then create a merge request to `<base>`:

```
1. Stage all changed files (git add <specific files>)
2. Commit using conventional commits format:
   feat: <concise description of what was implemented>
3. Push branch: git push -u origin <current branch>
4. Create PR to `<base>` using: gh pr create --base <base>
   - Title: same as commit message (append `({PROJECT}-<n>)` when started from a ticket)
   - Body: include summary, test plan, link back to the plan, and the ticket's browse URL if any
```

Report the PR URL to the user.

---

## Rules

- Never skip a phase
- Never proceed past planning without explicit user approval
- If any agent reports a blocking issue, stop and surface it to the user
- Keep the user informed at the end of each phase with a one-line status update
