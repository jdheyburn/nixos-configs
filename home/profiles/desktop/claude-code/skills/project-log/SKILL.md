---
name: project-log
description: Use when asked to update, write, or catch up the project log (e.g. "/project-log", "update the project log", "log this"), or at a milestone in a long-running project tracked in the Obsidian vault.
---

# Updating the project log

Long-running projects keep their history in the Obsidian vault at `~/Obsidian/Get-Started/projects/`. `projects/README.md` is the source of truth for layout, note templates, and the supersede and amend rules. This skill is the procedure for bringing a project up to date from the current session.

## Steps

1. **Read the conventions.** Read `~/Obsidian/Get-Started/projects/README.md` in full, even when you think you know it. Done when you have read it this session.
2. **Pick the project.** Follow "Picking a project" in the README. If no project matches, ask the user and stop until they answer.
3. **Read the project's current state.** Read `_index.md`, the last few entries of `log.md`, every open issue, and each decision the session touched. Done when you can say, for each thing the session changed, whether a note for it already exists.
4. **Inventory the session.** Go through the whole conversation, including anything compacted into a summary, and list each item under one of:
   - decisions made, including changes to earlier decisions
   - issues found, with their cause found, or resolved
   - work finished: PRs opened or merged, components whose state changed
   - follow-ups the user or you committed to

   Leave out work that isn't on this project. Done when every user turn has been checked against the list.
5. **Write.** For each item, create or update notes using the README templates. Update existing notes instead of creating duplicates. Record only what the session shows: a guess stays marked as unconfirmed, and a fact the session didn't establish stays out. Then append one `log.md` entry that links every note you touched, and update the matching rows in `_index.md`.
6. **Report.** Tell the user which notes you created and which you updated, with one line each. Also list the follow-ups you recorded and anything you left out and why.
