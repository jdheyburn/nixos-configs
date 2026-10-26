#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Scan for /review-round: PRs you review that are due another round, and the
worktrees, kind clusters and review memories that merged or closed PRs left behind.

Run from inside the repo checkout (any worktree):

  review_round.py scan [--json]
  review_round.py cleanup [--apply] [--json]

`scan` and `cleanup` without `--apply` change nothing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

DAY = 86400
ACTIVE_WINDOW = DAY  # a worktree touched this recently is in use
NO_PR_IDLE = 14 * DAY  # a worktree with no PR is removable once idle this long
# Keeps `git status` from refreshing the index, which would reset the idle clock.
GIT_ENV = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
WORKTREE_DIRS = (".worktrees", ".claude/worktrees")
PR_NAME = re.compile(r"^pr-(\d+)(?:-|$)")
# pr-<n>-review, plus the variants a review makes for a second shape (pr-203-review-w4).
REVIEW_CLUSTER = re.compile(r"^pr-(\d+)-review(?:-[a-z0-9-]+)?$")
MEMORY_FILE = re.compile(r"^project_pr(\d+)_review\.md$")
SHA_AT = re.compile(r"\bat ([0-9a-f]{7,40})\b")
# A cluster name, not the tail of a path such as `.worktrees/pr-490-review`.
CLUSTER_MENTION = re.compile(r"(?<![/\w-])(pr-\d+-review(?:-[a-z0-9]+)*)\b")
GITHUB_REMOTE = re.compile(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$")


# ---------------------------------------------------------------- pure helpers


def parse_worktrees(porcelain: str) -> list[dict]:
    """`git worktree list --porcelain` -> [{path, head, branch}]; branch is None when detached."""
    out, cur = [], None
    for line in porcelain.splitlines():
        key, _, val = line.partition(" ")
        if key == "worktree":
            cur = {"path": val, "head": None, "branch": None}
            out.append(cur)
        elif cur is not None and key == "HEAD":
            cur["head"] = val
        elif cur is not None and key == "branch":
            cur["branch"] = val.removeprefix("refs/heads/")
    return out


def pr_from_names(*names: str | None) -> int | None:
    for name in names:
        if name and (m := PR_NAME.match(name.rsplit("/", 1)[-1])):
            return int(m.group(1))
    return None


def project_slug(path: str) -> str:
    """The ~/.claude/projects directory name Claude Code uses for a cwd."""
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def parse_time(s: str | None) -> datetime | None:
    return datetime.fromisoformat(s) if s else None


def parse_memory(name: str, text: str) -> dict | None:
    """A `project_pr<N>_review.md` memory -> {pr, file, reviewedSha, clusters}."""
    m = MEMORY_FILE.match(name)
    if not m:
        return None
    description = next(
        (line.partition(":")[2].strip().strip("\"'") for line in text.splitlines() if line.startswith("description:")),
        "",
    )
    shas = SHA_AT.findall(description) or SHA_AT.findall(text)
    return {
        "pr": int(m.group(1)),
        "file": name,
        "reviewedSha": shas[-1] if shas else None,
        "clusters": sorted(set(CLUSTER_MENTION.findall(text))),
    }


def login(node: dict | None) -> str | None:
    return (node or {}).get("login")


def is_bot(author: dict | None) -> bool:
    return not author or author.get("__typename") == "Bot" or author.get("login", "").endswith("[bot]")


def thread_replies(pr: dict, me: str) -> list[dict]:
    """Threads you commented on where someone else (not a bot) wrote after your last comment."""
    out = []
    for thread in pr["reviewThreads"]["nodes"]:
        comments = thread["comments"]["nodes"]
        mine = [c["createdAt"] for c in comments if login(c["author"]) == me]
        if not mine:
            continue
        later = [
            c
            for c in comments
            if parse_time(c["createdAt"]) > parse_time(max(mine))
            and login(c["author"]) != me
            and not is_bot(c["author"])
        ]
        if later:
            last = later[-1]
            out.append(
                {
                    "path": thread["path"],
                    "by": login(last["author"]),
                    "url": last["url"],
                    "resolved": thread["isResolved"],
                }
            )
    return out


def review_status(pr: dict, me: str, memory: dict | None) -> dict:
    """Where an open PR stands for you as a reviewer.

    bucket is "first-review" (you have never reviewed it), "round-due" (something
    happened since your last review) or "waiting" (the ball is with the author).
    Your last submitted GitHub review is authoritative; the memory's SHA stands in
    when there is none, and a review that exists only in memory was never posted,
    so it is due. A review whose commit is null reviewed a commit the author has
    since force-pushed away.
    """
    mine = [r for r in pr["reviews"]["nodes"] if login(r["author"]) == me]
    submitted = sorted((r for r in mine if r["state"] != "PENDING"), key=lambda r: parse_time(r["submittedAt"]))
    last = submitted[-1] if submitted else None
    memory_sha = (memory or {}).get("reviewedSha")
    review_sha = (last.get("commit") or {}).get("oid") if last else None
    commit_gone = bool(last) and not review_sha
    reviewed_sha = review_sha or memory_sha
    reviewed_at = parse_time(last["submittedAt"]) if last else None
    head = pr["headRefOid"]
    head_moved = commit_gone or (bool(reviewed_sha) and not head.startswith(reviewed_sha))
    requested = any(login(n["requestedReviewer"]) == me for n in pr["reviewRequests"]["nodes"])
    replies = thread_replies(pr, me)
    comments = [
        {"by": login(c["author"]), "url": c["url"]}
        for c in pr["comments"]["nodes"]
        if reviewed_at
        and parse_time(c["createdAt"]) > reviewed_at
        and login(c["author"]) != me
        and not is_bot(c["author"])
    ]

    reasons = []
    if memory_sha and not last:
        reasons.append("review not posted")
    if requested and last:
        reasons.append("re-requested")
    if head_moved:
        reasons.append("new head")
    if replies:
        reasons.append(f"{len(replies)} thread repl{'y' if len(replies) == 1 else 'ies'}")
    if comments:
        reasons.append(f"{len(comments)} new comment{'' if len(comments) == 1 else 's'}")

    if not (last or memory_sha):
        bucket = "first-review"
    elif reasons:
        bucket = "round-due"
    else:
        bucket = "waiting"
    return {
        "bucket": bucket,
        "reasons": reasons,
        "lastState": last["state"] if last else None,
        "reviewedSha": reviewed_sha,
        "reviewedAt": last["submittedAt"] if last else None,
        "reviewedCommitGone": commit_gone,
        "memorySha": memory_sha if memory_sha and not (reviewed_sha or "").startswith(memory_sha) else None,
        "pendingDraft": any(r["state"] == "PENDING" for r in mine),
        "requested": requested,
        "replies": replies,
        "comments": comments,
    }


def worktree_decision(wt: dict, pr_state: str | None, now: float) -> tuple[bool, str]:
    """(remove?, reason). wt carries dirty, op, inUse, lastActive and unpushed (your commits only on this machine)."""
    if pr_state == "OPEN":
        return False, "open PR"
    if pr_state is None and now - wt["lastActive"] < NO_PR_IDLE:
        return False, "no PR, active in the last 14 days"
    if wt["dirty"]:
        return False, "uncommitted or untracked files"
    if wt["op"]:
        return False, f"{wt['op']} in progress"
    if wt["inUse"]:
        return False, "a process is running in it"
    if now - wt["lastActive"] < ACTIVE_WINDOW:
        return False, "active in the last 24 hours"
    if wt["unpushed"]:
        return False, f"{len(wt['unpushed'])} commit(s) of yours exist only here"
    if pr_state is None:
        return True, "no PR, idle 14 days, nothing of yours unpushed"
    return True, f"PR {pr_state.lower()}"


def orphan_kubeconfigs(paths: list[str], clusters: list[str]) -> list[str]:
    """`/tmp/kind-<name>.kubeconfig` files whose cluster no longer exists."""
    out = []
    for path in paths:
        name = Path(path).name.removeprefix("kind-").removesuffix(".kubeconfig")
        if name not in clusters:
            out.append(path)
    return sorted(out)


def cluster_decision(name: str, pr_state: str | None) -> tuple[bool, str]:
    if not REVIEW_CLUSTER.match(name):
        return False, "not a PR review cluster"
    if pr_state in ("MERGED", "CLOSED"):
        return True, f"PR {pr_state.lower()}"
    if pr_state == "OPEN":
        return False, "open PR"
    return False, "PR not found"


# ------------------------------------------------------------------------- I/O


def run(args: list[str], cwd: str | None = None, timeout: int = 60, check: bool = True) -> str:
    p = subprocess.run(args, cwd=cwd, env=GIT_ENV, check=False, capture_output=True, text=True, timeout=timeout)
    if check and p.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def gh_json(args: list[str], timeout: int = 60):
    return json.loads(run(["gh", *args], timeout=timeout))


def repo_root() -> Path:
    common = run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"]).strip()
    return Path(common).parent


def github_repo(root: Path) -> str:
    for remote in ("upstream", "origin"):
        url = run(["git", "-C", str(root), "remote", "get-url", remote], check=False).strip()
        if m := GITHUB_REMOTE.search(url):
            return m.group(1)
    raise RuntimeError("no GitHub remote named upstream or origin")


PR_FIELDS = """
number title url state isDraft mergedAt closedAt baseRefName headRefName headRefOid
author { login __typename }
reviewRequests(first: 30) { nodes { requestedReviewer { ... on User { login } } } }
reviews(last: 100) { nodes { author { login __typename } state submittedAt commit { oid } } }
reviewThreads(first: 100) {
  nodes { isResolved path comments(first: 50) { nodes { author { login __typename } createdAt url } } }
}
comments(last: 50) { nodes { author { login __typename } createdAt url } }
"""


def fetch_prs(repo: str, numbers: set[int], errors: list) -> dict[int, dict]:
    owner, name = repo.split("/")
    out: dict[int, dict] = {}
    ordered = sorted(numbers)
    for i in range(0, len(ordered), 10):
        batch = ordered[i : i + 10]
        fields = "\n".join(f"p{n}: pullRequest(number: {n}) {{ {PR_FIELDS} }}" for n in batch)
        query = f'{{ repository(owner: "{owner}", name: "{name}") {{ {fields} }} }}'
        # A number that is an issue, not a PR, nulls its alias and makes gh exit 1; keep the rest.
        raw = run(["gh", "api", "graphql", "-f", f"query={query}"], timeout=120, check=False)
        try:
            data = json.loads(raw)["data"]["repository"]
        except (json.JSONDecodeError, KeyError, TypeError):
            errors.append({"source": "github", "detail": f"PR batch {batch} failed"})
            continue
        for n in batch:
            if data.get(f"p{n}"):
                out[n] = data[f"p{n}"]
    return out


def _compare(repo: str, base: str, head: str) -> dict | None:
    p = subprocess.run(
        ["gh", "api", f"repos/{repo}/compare/{base}...{head}"], check=False, capture_output=True, text=True, timeout=60
    )
    return json.loads(p.stdout) if p.returncode == 0 else None


def since_review(repo: str, reviewed: str | None, head: str, base_ref: str) -> dict:
    """The PR's own non-merge commits from your reviewed SHA to the head; status
    "diverged" means the author rebased. Commits a base merge brought in are dropped."""
    if not reviewed:
        return {"status": "diverged"}
    c = _compare(repo, reviewed, head)
    if c is None:
        return {"status": "unknown"}
    own = _compare(repo, base_ref, head)
    own_shas = {x["sha"] for x in own["commits"]} if own else None
    commits = [x for x in c["commits"] if len(x["parents"]) == 1]
    kept = [x for x in commits if own_shas is None or x["sha"] in own_shas]
    return {
        "status": c["status"],
        "commits": [{"sha": x["sha"][:7], "subject": x["commit"]["message"].splitlines()[0]} for x in kept],
        "baseCommits": len(commits) - len(kept),
    }


def git_op(gitdir: Path) -> str | None:
    for marker, op in (
        ("MERGE_HEAD", "merge"),
        ("rebase-merge", "rebase"),
        ("rebase-apply", "rebase"),
        ("CHERRY_PICK_HEAD", "cherry-pick"),
        ("REVERT_HEAD", "revert"),
    ):
        if (gitdir / marker).exists():
            return op
    return None


def last_active(path: str, gitdir: Path) -> float:
    """Newest of the worktree's HEAD and reflog, and its Claude transcripts. The index is
    left out: any `git status` without GIT_OPTIONAL_LOCKS=0 rewrites it."""
    times = [p.stat().st_mtime for p in (gitdir / "HEAD", gitdir / "logs" / "HEAD") if p.exists()]
    transcripts = Path.home() / ".claude" / "projects" / project_slug(path)
    times += [f.stat().st_mtime for f in transcripts.glob("*.jsonl")]
    return max(times, default=0.0)


def process_cwds() -> list[str]:
    out = run(["lsof", "-d", "cwd", "-Fn"], timeout=60, check=False)
    return [line[1:] for line in out.splitlines() if line.startswith("n")]


def unpushed_mine(path: str, repo: str, head: str, email: str) -> list[str]:
    """Your commits in HEAD that exist only on this machine. A review checkout's commits
    are the PR author's (often a head since force-pushed away), so they don't count."""
    out = run(["git", "-C", path, "log", "HEAD", "--not", "--remotes", f"--author={email}", "--format=%h"], check=False)
    if not out.split():
        return []
    # A merged PR's branch is deleted, but GitHub keeps its head under refs/pull/<n>/head.
    p = subprocess.run(["gh", "api", f"repos/{repo}/commits/{head}", "--silent"], check=False, capture_output=True)
    return [] if p.returncode == 0 else out.split()


def probe_worktree(wt: dict, repo: str, email: str, cwds: list[str]) -> dict:
    path = wt["path"]
    gitdir = Path(run(["git", "-C", path, "rev-parse", "--absolute-git-dir"]).strip())
    return {
        **wt,
        "dirty": bool(run(["git", "-C", path, "status", "--porcelain"]).strip()),
        "op": git_op(gitdir),
        "inUse": any(c == path or c.startswith(path + "/") for c in cwds),
        "lastActive": last_active(path, gitdir),
        "unpushed": unpushed_mine(path, repo, wt["head"], email),
    }


def memory_dir(root: Path) -> Path:
    return Path.home() / ".claude" / "projects" / project_slug(str(root)) / "memory"


def load_memories(mdir: Path) -> dict[int, dict]:
    out = {}
    for f in sorted(mdir.glob("project_pr*_review.md")):
        if mem := parse_memory(f.name, f.read_text()):
            out[mem["pr"]] = mem
    return out


def scan(include_round: bool = True) -> dict:
    errors: list[dict] = []
    root = repo_root()
    repo = github_repo(root)
    me = run(["gh", "api", "user", "--jq", ".login"]).strip()
    email = run(["git", "-C", str(root), "config", "user.email"]).strip()
    mdir = memory_dir(root)
    memories = load_memories(mdir)

    worktrees = [
        wt
        for wt in parse_worktrees(run(["git", "-C", str(root), "worktree", "list", "--porcelain"]))
        if any(wt["path"].startswith(f"{root}/{d}/") for d in WORKTREE_DIRS)
    ]
    try:
        clusters = run(["kind", "get", "clusters"], timeout=30).split()
        kind_ok = True
    except (RuntimeError, FileNotFoundError, subprocess.TimeoutExpired) as e:
        clusters, kind_ok = [], False
        errors.append({"source": "kind", "detail": str(e)})

    review_prs: set[int] = set()
    if include_round:
        for query in ("review-requested:@me", "reviewed-by:@me -author:@me"):
            listed = gh_json(["pr", "list", "--repo", repo, "--state", "open", "--search", query, "--json", "number"])
            review_prs |= {p["number"] for p in listed}

    # Your own PRs, so a worktree on one of your branches maps to its PR.
    own = gh_json(
        [
            "pr",
            "list",
            "--repo",
            repo,
            "--author",
            "@me",
            "--state",
            "all",
            "--limit",
            "300",
            "--json",
            "number,headRefName,state",
        ]
    )
    by_branch: dict[str, int] = {}
    for p in sorted(own, key=lambda p: (p["state"] == "OPEN", p["number"])):
        by_branch[p["headRefName"]] = p["number"]
    for wt in worktrees:
        wt["pr"] = pr_from_names(wt["path"], wt["branch"]) or by_branch.get(wt["branch"] or "")

    wanted = review_prs | set(memories) | {wt["pr"] for wt in worktrees if wt["pr"]}
    wanted |= {int(m.group(1)) for c in clusters if (m := REVIEW_CLUSTER.match(c))}
    prs = fetch_prs(repo, wanted, errors)

    def state(n: int | None) -> str | None:
        return prs[n]["state"] if n in prs else None

    # Review round.
    round_ = {"firstReview": [], "roundDue": [], "waiting": []}
    if include_round:
        open_reviews = {n for n in review_prs | set(memories) if state(n) == "OPEN" and login(prs[n]["author"]) != me}
        for n in sorted(open_reviews):
            pr = prs[n]
            st = review_status(pr, me, memories.get(n))
            entry = {
                "pr": n,
                "url": pr["url"],
                "title": pr["title"],
                "author": login(pr["author"]),
                "isDraft": pr["isDraft"],
                "headOid": pr["headRefOid"],
                "memory": memories[n]["file"] if n in memories else None,
                **st,
            }
            if st["bucket"] == "round-due" and "new head" in st["reasons"]:
                gone = st["reviewedCommitGone"] and not st["reviewedSha"]
                entry["sinceReview"] = since_review(
                    repo, None if gone else st["reviewedSha"], pr["headRefOid"], pr["baseRefName"]
                )
            key = {"first-review": "firstReview", "round-due": "roundDue", "waiting": "waiting"}[st["bucket"]]
            round_[key].append(entry)

    # Cleanup.
    now = time.time()
    cwds = process_cwds()
    candidates = [wt for wt in worktrees if state(wt["pr"]) != "OPEN"]
    with ThreadPoolExecutor(8) as pool:
        probed = list(pool.map(lambda wt: probe_worktree(wt, repo, email, cwds), candidates))
    wt_remove, wt_keep = [], []
    for wt in probed + [wt for wt in worktrees if state(wt["pr"]) == "OPEN"]:
        if "dirty" in wt:
            remove, reason = worktree_decision(wt, state(wt["pr"]), now)
        else:
            remove, reason = False, "open PR"
        row = {"path": wt["path"], "branch": wt["branch"], "pr": wt["pr"], "prState": state(wt["pr"]), "reason": reason}
        (wt_remove if remove else wt_keep).append(row)

    cl_remove, cl_keep = [], []
    for c in clusters:
        m = REVIEW_CLUSTER.match(c)
        n = int(m.group(1)) if m else None
        remove, reason = cluster_decision(c, state(n))
        (cl_remove if remove else cl_keep).append({"name": c, "pr": n, "reason": reason})
    # Without a cluster list every kubeconfig would look orphaned.
    kubeconfigs = (
        orphan_kubeconfigs([str(p) for p in Path("/tmp").glob("kind-*.kubeconfig")], clusters) if kind_ok else []
    )

    memory_rows = [
        {
            "pr": n,
            "file": mem["file"],
            "prState": state(n),
            "clusters": [{"name": c, "exists": c in clusters} for c in mem["clusters"]],
        }
        for n, mem in sorted(memories.items())
    ]

    return {
        "repo": repo,
        "root": str(root),
        "me": me,
        "memoryDir": str(mdir),
        "errors": errors,
        "round": round_,
        "cleanup": {
            "worktrees": {
                "remove": sorted(wt_remove, key=lambda r: r["path"]),
                "keep": sorted(wt_keep, key=lambda r: r["path"]),
            },
            "clusters": {"remove": cl_remove, "keep": cl_keep},
            "kubeconfigs": {"remove": kubeconfigs},
        },
        "memories": memory_rows,
    }


def apply_cleanup(result: dict) -> dict:
    root = result["root"]
    done = {"worktrees": [], "clusters": [], "failed": []}
    for row in result["cleanup"]["worktrees"]["remove"]:
        # No --force: git refuses a worktree that turned dirty since the scan.
        p = subprocess.run(
            ["git", "-C", root, "worktree", "remove", row["path"]], check=False, capture_output=True, text=True
        )
        (done["worktrees"] if p.returncode == 0 else done["failed"]).append(
            row["path"] if p.returncode == 0 else {"path": row["path"], "error": p.stderr.strip()}
        )
    run(["git", "-C", root, "worktree", "prune"], check=False)
    for row in result["cleanup"]["clusters"]["remove"]:
        p = subprocess.run(
            ["kind", "delete", "cluster", "--name", row["name"]],
            check=False,
            capture_output=True,
            text=True,
            timeout=300,
        )
        if p.returncode == 0:
            done["clusters"].append(row["name"])
            Path(f"/tmp/kind-{row['name']}.kubeconfig").unlink(missing_ok=True)
        else:
            done["failed"].append({"cluster": row["name"], "error": p.stderr.strip()})
    for path in result["cleanup"]["kubeconfigs"]["remove"]:
        Path(path).unlink(missing_ok=True)
    done["kubeconfigs"] = result["cleanup"]["kubeconfigs"]["remove"]
    return done


# ------------------------------------------------------------------- rendering


def short(sha: str | None) -> str:
    return sha[:7] if sha else "?"


def round_markdown(r: dict) -> list[str]:
    rr = r["round"]
    out = [f"## Review round ({r['repo']})", ""]
    out.append(f"### Round due ({len(rr['roundDue'])})")
    for e in rr["roundDue"]:
        draft = " [draft]" if e["isDraft"] else ""
        out.append(f"- #{e['pr']} {e['title']} (@{e['author']}){draft}: {', '.join(e['reasons'])}")
        out.append(
            f"  - last review {e['lastState'] or 'memory only'} at {short(e['reviewedSha'])}, head {short(e['headOid'])}"
        )
        if s := e.get("sinceReview"):
            if s["status"] == "diverged" or e["reviewedCommitGone"]:
                out.append("  - rebased since your review: compare with `git range-diff`")
            elif s["status"] == "unknown":
                out.append("  - could not compare the reviewed SHA with the head")
            else:
                out += [f"  - {c['sha']} {c['subject']}" for c in s["commits"]]
                if s["baseCommits"]:
                    out.append(f"  - plus {s['baseCommits']} commit(s) from merging the base branch")
        out += [
            f"  - reply by @{x['by']} on {x['path']}{' (resolved)' if x['resolved'] else ''}: {x['url']}"
            for x in e["replies"]
        ]
        out += [f"  - comment by @{x['by']}: {x['url']}" for x in e["comments"]]
        if e["pendingDraft"]:
            out.append("  - you have a pending review draft")
        if e["memorySha"]:
            out.append(f"  - memory says reviewed at {e['memorySha']}")
    out += ["", f"### First review ({len(rr['firstReview'])})"]
    out += [f"- #{e['pr']} {e['title']} (@{e['author']})" for e in rr["firstReview"]]
    out += ["", f"### Waiting on the author ({len(rr['waiting'])})"]
    out += [
        f"- #{e['pr']} {e['title']} (@{e['author']}): {e['lastState'] or 'memory only'} at {short(e['reviewedSha'])}"
        for e in rr["waiting"]
    ]
    return out + [""]


def cleanup_markdown(r: dict) -> list[str]:
    c = r["cleanup"]
    out = ["## Cleanup", "", f"### Worktrees to remove ({len(c['worktrees']['remove'])})"]
    out += [f"- {w['path'].removeprefix(r['root'] + '/')}: {w['reason']}" for w in c["worktrees"]["remove"]]
    kept_closed = [w for w in c["worktrees"]["keep"] if w["prState"] in ("MERGED", "CLOSED")]
    out += ["", f"### Kept, although the PR is merged or closed ({len(kept_closed)})"]
    out += [f"- {w['path'].removeprefix(r['root'] + '/')} (#{w['pr']}): {w['reason']}" for w in kept_closed]
    counts: dict[str, int] = {}
    for w in c["worktrees"]["keep"]:
        if w not in kept_closed:
            counts[w["reason"]] = counts.get(w["reason"], 0) + 1
    out += ["", "### Other worktrees kept"] + [f"- {n}: {reason}" for reason, n in sorted(counts.items())]
    out += ["", f"### kind clusters to delete ({len(c['clusters']['remove'])})"]
    out += [f"- {k['name']}: {k['reason']}" for k in c["clusters"]["remove"]]
    out += [f"- kept {k['name']}: {k['reason']}" for k in c["clusters"]["keep"]]
    out += ["", f"### Orphaned kubeconfigs to remove ({len(c['kubeconfigs']['remove'])})"]
    out += [f"- {k}" for k in c["kubeconfigs"]["remove"]]
    return out + [""]


def memories_markdown(r: dict) -> list[str]:
    out = ["## Review memories", ""]
    for m in r["memories"]:
        notes = []
        if m["prState"] in ("MERGED", "CLOSED"):
            notes.append(f"PR {m['prState'].lower()}, retire")
        gone = [c["name"] for c in m["clusters"] if not c["exists"]]
        if gone:
            notes.append(f"names cluster {', '.join(gone)}, which no longer exists")
        if notes:
            out.append(f"- {m['file']} (#{m['pr']}): {'; '.join(notes)}")
    return out + [""]


def errors_markdown(r: dict) -> list[str]:
    return ["## Errors", ""] + [f"- {e['source']}: {e['detail']}" for e in r["errors"]] + [""] if r["errors"] else []


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scan", help="review round, cleanup plan and memory notes (read-only)")
    s.add_argument("--json", action="store_true")
    c = sub.add_parser("cleanup", help="cleanup plan; --apply removes what it lists")
    c.add_argument("--apply", action="store_true")
    c.add_argument("--json", action="store_true")
    args = ap.parse_args()

    result = scan(include_round=args.cmd == "scan")
    if args.cmd == "cleanup" and args.apply:
        result["applied"] = apply_cleanup(result)

    if args.json:
        json.dump(result, sys.stdout, indent=2)
        print()
        return
    lines = errors_markdown(result)
    if args.cmd == "scan":
        lines += round_markdown(result)
    lines += cleanup_markdown(result) + memories_markdown(result)
    if applied := result.get("applied"):
        lines += [
            "## Applied",
            "",
            (
                f"- removed {len(applied['worktrees'])} worktrees, deleted {len(applied['clusters'])} clusters,"
                f" removed {len(applied['kubeconfigs'])} orphaned kubeconfigs"
            ),
        ] + [f"- failed: {f}" for f in applied["failed"]]
    print("\n".join(lines))


if __name__ == "__main__":
    main()
