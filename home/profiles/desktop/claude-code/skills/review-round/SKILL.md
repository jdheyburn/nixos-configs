---
name: review-round
description: One pass over the PRs you review: which are due another round and what changed, start the round-2 kind reviews in Herdr tabs, and clean up worktrees, kind clusters and review memories that merged or closed PRs left behind.
disable-model-invocation: true
---

# Review round

Run from inside the repo checkout. `scripts/review_round.py` does the GitHub, git and kind reads and the classification; you triage what it finds and carry out the cleanup the user approves. Built for valkey-operator, whose PR reviews leave a `.worktrees/pr-<n>*` checkout, a `pr-<n>-review` kind cluster and a `project_pr<n>_review.md` memory (see `review-valkey-operator-pr`).

## 1. Scan

```bash
uv run --script ~/.claude/skills/review-round/scripts/review_round.py scan > <scratchpad>/round.md
uv run --script ~/.claude/skills/review-round/scripts/review_round.py scan --json > <scratchpad>/round.json
```

Read `round.md`; take exact fields (URLs, SHAs, paths) from `round.json`. An `Errors` section means part of the scan is missing: say which in the report. The scan changes nothing.

It sorts each open PR you review (review requested, reviewed by you, or named by a review memory) into:

- **Round due**: something happened since your last review (a new head, a re-request, replies on your threads, or new comments), or your review exists only in memory and was never posted. "Rebased since your review" means the commit you reviewed is no longer in the PR, so the commit list is unavailable.
- **First review**: you have never reviewed it.
- **Waiting on the author**: nothing since your last review.

Your last submitted GitHub review sets the reviewed SHA. The memory's SHA stands in when there is none.

## 2. Triage round-due PRs

Start one background `general-purpose` subagent per round-due PR, all at once, with this prompt filled in:

> Triage PR <url> for its reviewer's next round. Post, edit and push nothing. To run a test, check the head out in a throwaway worktree (`git -C <root> worktree add --detach <your scratchpad>/pr-<pr> <headOid>`) and remove it (`git -C <root> worktree remove --force <path>`) before you return.
> The reviewer last reviewed `<reviewedSha>`; the head is now `<headOid>`.
> <memory file non-null:> Their review notes are in `<memoryDir>/<memory>`. Its numbered asks (R1, R2, …, nits, API asks) are the **open asks**.
> <memory null:> There are no review notes. Take the open asks from the reviewer's (`<me>`) review comments and threads on the PR.
> What changed: <the scan's commit lines, or "the author rebased; run `git fetch upstream pull/<pr>/head` and `git range-diff <reviewedSha>...FETCH_HEAD` from <root>, or read `gh pr diff <pr>` if the reviewed SHA is not local">. Replies and comments since the review: <the scan's reply and comment URLs>.
> Read every commit's diff and every reply in full. Return:
> - each open ask, one line: **addressed** (commit and how), **answered** (the reply's gist, and whether it agrees or pushes back), or **untouched**
> - anything new in the diff that no ask covers, flagged as needing a look
> - the next step, one of: approve; re-run the kind validation (`/review-valkey-operator-pr <pr>`) because behaviour changed, naming which scenarios; reply to a thread (which); or wait on the author (for what).

The triage is done when every open ask of every round-due PR has one of the three statuses.

## 3. Plan

The plan has the reviews to start and the cleanup.

**Reviews to start**: every round-due PR whose triage next step is a kind re-run. Leave out a PR that already has a live agent named `review-<n>` (`herdr agent list`); name it in the report instead.

**Cleanup**: the scan's `Cleanup` and `Review memories` sections:

- **Worktrees to remove**: under `.worktrees/` or `.claude/worktrees/`, PR merged or closed (or no PR and idle 14 days), clean, no merge or rebase in progress, no process running in it, idle 24 hours, and none of your commits exist only there.
- **kind clusters to delete**: `pr-<n>-review` clusters whose PR merged or closed.
- **Orphaned kubeconfigs**: `/tmp/kind-<name>.kubeconfig` files whose cluster no longer exists.
- **Review memories**: a memory whose PR merged or closed is to retire. A memory that names a cluster which no longer exists is stale. Read each such memory now. Plan a retiring memory as a delete, unless it records something still unraised (a follow-up, a candidate issue, an F-numbered finding marked not raised): then plan to rewrite it down to that item and the line "PR merged <date>". Plan a stale memory as an edit that says the cluster was deleted. Each memory change includes its line in `MEMORY.md`.

Put the plan to the user in one message: the reviews to start, the cleanup counts, every memory change, and each worktree kept although its PR merged, with the reason. For a worktree kept because your commits exist only there, add `git -C <path> log --oneline HEAD --not --remotes` so the user can judge them. Wait for approval.

## 4. Apply the cleanup

On approval:

```bash
uv run --script ~/.claude/skills/review-round/scripts/review_round.py cleanup --apply
```

It re-scans first, so anything that changed since step 1 drops out of the plan. It runs `git worktree remove` without `--force`, prunes, deletes the clusters, removes their kubeconfigs and the orphaned ones, and keeps branches. Then make the approved memory changes. A worktree the user wants gone despite a keep reason is theirs to remove with `--force`.

## 5. Start the reviews

Each approved review runs as a Claude agent named `review-<n>` in its own Herdr tab. This needs `HERDR_ENV=1`; without it, write each prompt to `<scratchpad>/review-<n>.md` and list them in the report for the user to start.

Run at most **2** reviews at once: each builds an image and a kind cluster, and Docker has about 7.7 GiB. Start the first two, in the order the plan lists them:

```bash
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <root> --label "review #<n>" --no-focus
herdr agent start review-<n> --kind claude --pane <.result.root_pane.pane_id>
herdr agent prompt review-<n> "<prompt>"
```

The prompt is `/review-valkey-operator-pr <n>` on its first line, then: "This is round <k>. Re-validate from these open asks and focus the kind scenarios on what changed since `<reviewedSha>`:" and the PR's triage block from step 2, verbatim.

For each running review, wait in the background (Bash `run_in_background`): `herdr agent wait review-<n> --timeout 5400000`. When one returns, read `herdr agent get review-<n>`:

- `done` or `idle`: the review finished. Start the next queued review.
- `blocked`: it is waiting on the user (a permission prompt or a question). Name it to the user and wait on it again. Answering it is the user's call.
- a timeout or `unknown`: read `herdr agent read review-<n> --source recent-unwrapped --lines 80`, tell the user where it stands, and leave its slot taken.

The round leaves every tab it opened in place: the user reads the review there.

## 6. Report

Write the report once the first reviews are started; follow up as each finishes.

1. **Round due**: per PR, its link, the open asks with their statuses, anything new, and the next step. Then first-review PRs as links.
2. **Reviews**: each `review-<n>` agent with its status (started, queued, blocked, done), and any review skipped because one was already live.
3. **Cleanup**: worktrees removed and clusters deleted (counts), failures with their errors, and the worktrees kept for a merged or closed PR.
4. **Memories**: each file deleted, rewritten or edited.

## Tests

`uv run --no-project --with pytest pytest -p no:cacheprovider ~/.claude/skills/review-round/scripts`
