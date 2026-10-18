# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Replay restic snapshots of the vault into a fresh git history, once.

Read-only against restic: only `snapshots` and `restore` are allowed. Restores
go to a scratch directory; the live vault is never touched. Each snapshot that
changed tracked content becomes a commit dated to the snapshot time. At the
end the newest commit is checked against the newest snapshot, and a report
lists every file that some snapshot held but the newest one doesn't.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from history import MANIFEST_PATH, _git, commit_snapshot, ensure_repo
from vault import build_manifest, list_files

ALLOWED_SUBCOMMANDS = frozenset({"snapshots", "restore"})


class Restic:
    def __init__(self, cmd: list[str]):
        self.cmd = cmd

    def run(self, subcommand: str, *args: str) -> str:
        if subcommand not in ALLOWED_SUBCOMMANDS:
            raise ValueError(f"restic {subcommand} is not allowed in backfill")
        return self._exec([subcommand, *args])

    def _exec(self, args: list[str]) -> str:
        return subprocess.run([*self.cmd, *args], check=True, capture_output=True, text=True).stdout


@dataclass(frozen=True)
class Snapshot:
    id: str
    time: datetime


@dataclass
class BackfillResult:
    snapshots: int
    commits: int
    lost: dict[str, str]


def _parse_time(value: str) -> datetime:
    # restic prints nanoseconds; fromisoformat takes at most microseconds
    value = re.sub(r"(\.\d{6})\d+", r"\1", value)
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def list_snapshots(restic: Restic, path: str) -> list[Snapshot]:
    raw = json.loads(restic.run("snapshots", "--json", "--path", path))
    snaps = [Snapshot(s["id"], _parse_time(s["time"])) for s in raw]
    return sorted(snaps, key=lambda s: s.time)


def restore(restic: Restic, snapshot: Snapshot, path: str, scratch: Path) -> None:
    # --retry-lock waits out the hourly forget --prune's exclusive lock
    restic.run(
        "restore",
        f"{snapshot.id}:{path}",
        "--target", str(scratch),
        "--delete",
        "--overwrite", "if-changed",
        "--retry-lock", "30m",
    )  # fmt: skip


def _overlaps(a: Path, b: Path) -> bool:
    a, b = a.resolve(), b.resolve()
    return a == b or a.is_relative_to(b) or b.is_relative_to(a)


def backfill(
    restic: Restic,
    snapshot_path: str,
    git_dir: Path,
    scratch: Path,
    exclude_file: Path,
    vault: Path,
    restore_path: str | None = None,
) -> BackfillResult:
    """Replay snapshots of `snapshot_path`, restoring `restore_path` (default: the same) from each."""
    restore_path = restore_path or snapshot_path
    if git_dir.exists():
        raise ValueError(f"{git_dir} already exists; backfill only writes a fresh repo")
    if _overlaps(scratch, vault):
        raise ValueError(f"scratch {scratch} overlaps the vault {vault}")

    snapshots = list_snapshots(restic, snapshot_path)
    if not snapshots:
        raise ValueError(f"no restic snapshots for {snapshot_path}")

    ensure_repo(git_dir, exclude_file)
    scratch.mkdir(parents=True, exist_ok=True)
    last_seen: dict[str, str] = {}
    current: list[str] = []
    commits = 0
    for n, snap in enumerate(snapshots, 1):
        restore(restic, snap, restore_path, scratch)
        current = list_files(scratch)
        for rel in current:
            last_seen[rel] = snap.id
        message = f"Backfill from restic snapshot {snap.id} ({snap.time:%Y-%m-%dT%H:%M:%S%z})"
        committed = commit_snapshot(git_dir, scratch, build_manifest(scratch), message, when=snap.time)
        commits += committed
        print(f"[{n}/{len(snapshots)}] {snap.id} {snap.time.isoformat()} files={len(current)} committed={committed}")

    _verify(git_dir, scratch)
    lost = {rel: sid for rel, sid in last_seen.items() if rel not in set(current)}
    return BackfillResult(snapshots=len(snapshots), commits=commits, lost=lost)


def _verify(git_dir: Path, scratch: Path) -> None:
    status = _git(
        git_dir, "status", "--porcelain", "--", ".", f":!{MANIFEST_PATH}", work_tree=scratch
    ).stdout
    if status:
        raise RuntimeError(f"HEAD does not match the newest snapshot:\n{status}")
    if _git(git_dir, "show", f"HEAD:{MANIFEST_PATH}").stdout != build_manifest(scratch):
        raise RuntimeError("HEAD attachment manifest does not match the newest snapshot")


def write_report(lost: dict[str, str], report: Path) -> None:
    report.write_text("".join(f"{rel}\t{sid}\n" for rel, sid in sorted(lost.items())), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--restic", required=True, help="restic command, e.g. restic-obsidian")
    parser.add_argument("--snapshot-path", required=True, help="path the restic snapshots were taken of")
    parser.add_argument("--restore-path", help="folder within the snapshots holding the vault (default: --snapshot-path)")
    parser.add_argument("--git-dir", type=Path, required=True)
    parser.add_argument("--scratch", type=Path, required=True)
    parser.add_argument("--exclude-file", type=Path, required=True)
    parser.add_argument("--vault", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(argv)

    result = backfill(
        Restic(shlex.split(args.restic)),
        args.snapshot_path,
        args.git_dir,
        args.scratch,
        args.exclude_file,
        args.vault,
        restore_path=args.restore_path,
    )
    write_report(result.lost, args.report)
    print(
        f"snapshots={result.snapshots} commits={result.commits} lost={len(result.lost)} "
        f"report={args.report} (HEAD verified against newest snapshot)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
