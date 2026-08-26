---
name: implement-issue
description: Use when asked to implement a valkey-operator GitHub issue end to end (e.g. "/implement-issue 265", "pick up issue 187", "implement this issue").
---

# Implementing a GitHub issue

Take an issue from triage to verified changes ready for your human partner to commit:
brainstorm the design first, then plan, implement with TDD in a worktree, and verify.

## Workflow

1. **Resolve the issue.** `gh issue view <n> --json title,body,labels,comments`. Follow
   links to related issues/PRs and any specs under `docs/superpowers/specs/`. Check for
   prior art: existing branches/worktrees, recently merged PRs touching the same area.
2. **Brainstorm.** REQUIRED SUB-SKILL: superpowers:brainstorming. Explore intent and
   design with your human partner before any plan or code. If the issue already links an
   approved spec, brainstorming may be short — confirm the spec still holds, don't redo it.
3. **Plan.** REQUIRED SUB-SKILL: superpowers:writing-plans. Present the plan as a
   suggestion and wait for explicit approval before touching code.
4. **Isolate.** REQUIRED SUB-SKILL: superpowers:using-git-worktrees — worktree under
   `.worktrees/`, branch named per CONTRIBUTING.md.
5. **Implement.** REQUIRED SUB-SKILL: superpowers:test-driven-development. Follow
   `docs/architecture.md` conventions; update `docs/` when behavior or API changes.
6. **Verify.** REQUIRED SUB-SKILL: superpowers:verification-before-completion. Run the
   relevant `make` targets (unit/lint at minimum) and capture output. For changes needing
   cluster validation, print the kind runbook — don't run slow docker builds unless asked.
7. **Hand off.** Never run `git add`/`git commit`/`git push` — your human partner stages
   and commits. Report: changed files, verification evidence, a suggested commit message,
   and a draft PR description referencing the issue (`Fixes #<n>`) and relevant docs.
