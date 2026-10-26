"""Remove the worktrees of ended Remote Control sessions.

A worktree-mode session leaves its git worktree in <repo>/.claude/worktrees/,
and the branch it checked out stays checked out there, so a later session
can't check that branch out. A worktree is removed when the server has
unlocked it (it locks a worktree while its session is live), it has no local
changes, and every commit in it is on origin. Its local branch goes with it.
"""

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Worktree:
    path: Path
    branch: str | None
    locked: bool


def git(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)


def worktrees(repo: Path) -> list[Worktree]:
    found = []
    for block in git(repo, "worktree", "list", "--porcelain").stdout.split("\n\n"):
        fields = dict((line.split(" ", 1) + [""])[:2] for line in block.splitlines())
        if "worktree" not in fields:
            continue
        branch = fields.get("branch", "").removeprefix("refs/heads/") or None
        found.append(Worktree(Path(fields["worktree"]), branch, "locked" in fields))
    return found


def removable(wt: Worktree) -> bool:
    if wt.locked or not wt.path.is_dir():
        return False
    status = git(wt.path, "status", "--porcelain")
    if status.returncode != 0 or status.stdout:
        return False
    unpushed = git(wt.path, "rev-list", "HEAD", "--not", "--remotes")
    return unpushed.returncode == 0 and not unpushed.stdout


def prune(repo: Path) -> list[Path]:
    # Without a current view of origin, a deleted remote branch would still
    # count as pushed.
    fetch = git(repo, "fetch", "-q", "--prune", "origin")
    if fetch.returncode != 0:
        print(f"{repo}: fetch failed, skipping: {fetch.stderr.strip()}", file=sys.stderr)
        return []

    sessions = (repo / ".claude" / "worktrees").resolve()
    removed = []
    for wt in worktrees(repo):
        if wt.path.resolve().parent != sessions or not removable(wt):
            continue
        result = git(repo, "worktree", "remove", str(wt.path))
        if result.returncode != 0:
            print(f"{wt.path}: {result.stderr.strip()}", file=sys.stderr)
            continue
        if wt.branch:
            git(repo, "branch", "-q", "-D", wt.branch)
        print(f"removed {wt.path}")
        removed.append(wt.path)

    git(repo, "worktree", "prune")
    return removed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repos", nargs="+", type=Path)
    for repo in parser.parse_args().repos:
        if (repo / ".git").exists():
            prune(repo)


if __name__ == "__main__":
    main()
