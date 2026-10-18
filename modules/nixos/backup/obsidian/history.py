# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Hourly vault history on charlie.

Checks for missing attachments, commits the vault's text files and an
attachment manifest to a bare git repo, then pings healthchecks: success when
nothing is missing, /fail with the missing references otherwise. Nothing is
ever written into the vault itself.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

from vault import build_manifest, missing_attachments

MANIFEST_PATH = "attachments.manifest"
IDENTITY = {
    "GIT_AUTHOR_NAME": "obsidian",
    "GIT_AUTHOR_EMAIL": "obsidian@charlie",
    "GIT_COMMITTER_NAME": "obsidian",
    "GIT_COMMITTER_EMAIL": "obsidian@charlie",
}


def _git(
    git_dir: Path,
    *args: str,
    work_tree: Path | None = None,
    input: str | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    cmd = ["git", "-c", "core.quotePath=false", "--git-dir", str(git_dir)]
    if work_tree is not None:
        cmd += ["--work-tree", str(work_tree)]
    return subprocess.run(
        [*cmd, *args],
        cwd=work_tree,
        input=input,
        env={**os.environ, **(env or {})},
        check=check,
        capture_output=True,
        text=True,
    )


def ensure_repo(git_dir: Path, exclude_file: Path) -> None:
    """Create the bare repo if missing and install the tracking rules."""
    if not git_dir.exists():
        subprocess.run(
            ["git", "init", "--quiet", "--bare", "--shared=group", "--initial-branch=main", str(git_dir)],
            check=True,
            capture_output=True,
        )
    (git_dir / "info").mkdir(exist_ok=True)
    shutil.copyfile(exclude_file, git_dir / "info" / "exclude")


def commit_snapshot(
    git_dir: Path, work_tree: Path, manifest: str, message: str, when: datetime | None = None
) -> bool:
    """Stage the work tree plus the manifest and commit if anything changed."""
    _git(git_dir, "add", "-A", work_tree=work_tree)
    sha = _git(git_dir, "hash-object", "-w", "--stdin", input=manifest).stdout.strip()
    _git(git_dir, "update-index", "--add", "--cacheinfo", f"100644,{sha},{MANIFEST_PATH}")

    has_head = _git(git_dir, "rev-parse", "--verify", "--quiet", "HEAD", check=False).returncode == 0
    if has_head and _git(git_dir, "diff", "--cached", "--quiet", "HEAD", check=False).returncode == 0:
        return False

    env = dict(IDENTITY)
    if when is not None:
        stamp = when.isoformat()
        env |= {"GIT_AUTHOR_DATE": stamp, "GIT_COMMITTER_DATE": stamp}
    _git(git_dir, "commit", "--quiet", "--no-verify", "-m", message, work_tree=work_tree, env=env)
    return True


def ping_healthcheck(url: str, ok: bool, body: str) -> None:
    target = url if ok else f"{url}/fail"
    request = urllib.request.Request(target, data=body.encode(), method="POST")
    with urllib.request.urlopen(request, timeout=10):
        pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", type=Path, required=True)
    parser.add_argument("--git-dir", type=Path, required=True)
    parser.add_argument("--exclude-file", type=Path, required=True)
    parser.add_argument("--ignore-file", type=Path, required=True)
    parser.add_argument("--healthcheck", required=True)
    args = parser.parse_args(argv)

    ignored = {line.strip() for line in args.ignore_file.read_text().splitlines() if line.strip()}

    ensure_repo(args.git_dir, args.exclude_file)
    missing = missing_attachments(args.vault, ignored)
    now = datetime.now(UTC)
    committed = commit_snapshot(
        args.git_dir, args.vault, build_manifest(args.vault), f"Snapshot {now:%Y-%m-%dT%H:%M:%SZ}"
    )
    print(f"committed={committed} missing={len(missing)}")

    body = "".join(f"{r.note}: {r.target}\n" for r in missing)
    if body:
        print(body, end="")
    ping_healthcheck(args.healthcheck, not missing, body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
