import json
import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path

import pytest

from backfill import Restic, backfill, main
from history import commit_snapshot, ensure_repo

EXCLUDE = Path(__file__).parent / "vault-exclude"
SNAPSHOT_PATH = "/var/lib/obsidian/repo"

SNAPSHOTS = {
    "aaa": ("2024-12-17T10:00:01.123456789+00:00", {"n.md": b"1", "p.png": b"x", "notes/Café.md": b"c"}),
    "bbb": ("2024-12-17T11:00:00Z", {"n.md": b"1", "p.png": b"x", "notes/Café.md": b"c"}),
    "ccc": ("2024-12-18T09:30:00+01:00", {"n.md": b"2", "notes/Café.md": b"c"}),
}


class FakeRestic(Restic):
    """Serves snapshots from memory; restore mirrors one into the target."""

    def __init__(self, snapshots: dict[str, tuple[str, dict[str, bytes]]]):
        super().__init__(["restic"])
        self.snapshots = snapshots
        self.calls: list[list[str]] = []

    def _exec(self, args: list[str]) -> str:
        self.calls.append(args)
        if args[0] == "snapshots":
            # restic lists newest last, but don't rely on order
            return json.dumps(
                [{"id": i, "time": t, "paths": [SNAPSHOT_PATH]} for i, (t, _) in reversed(self.snapshots.items())]
            )
        assert args[0] == "restore"
        snap_id, path = args[1].split(":", 1)
        assert path == SNAPSHOT_PATH or path.startswith(SNAPSHOT_PATH + "/")
        prefix = path[len(SNAPSHOT_PATH) + 1 :]
        target = Path(args[args.index("--target") + 1])
        if target.exists():
            shutil.rmtree(target)
        for rel, content in self.snapshots[snap_id][1].items():
            if prefix:
                if not rel.startswith(prefix + "/"):
                    continue
                rel = rel[len(prefix) + 1 :]
            (target / rel).parent.mkdir(parents=True, exist_ok=True)
            (target / rel).write_bytes(content)
        return ""


@pytest.fixture
def paths(tmp_path: Path) -> dict[str, Path]:
    vault = tmp_path / "repo"
    vault.mkdir()
    (vault / "live.md").write_text("live")
    return {"vault": vault, "git_dir": tmp_path / "history.git", "scratch": tmp_path / "backfill"}


def run_backfill(fake: FakeRestic, paths: dict[str, Path]):
    return backfill(fake, SNAPSHOT_PATH, paths["git_dir"], paths["scratch"], EXCLUDE, paths["vault"])


def git(git_dir: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "--git-dir", str(git_dir), *args], check=True, capture_output=True, text=True
    ).stdout


@pytest.mark.parametrize("sub", ["forget", "prune", "unlock", "backup", "rebuild-index", "init", "rewrite"])
def test_rejects_write_subcommands(sub: str) -> None:
    restic = Restic(["/nonexistent/restic"])
    with pytest.raises(ValueError):
        restic.run(sub)


def test_replays_snapshots_as_dated_commits(paths: dict[str, Path]) -> None:
    result = run_backfill(FakeRestic(SNAPSHOTS), paths)
    assert (result.snapshots, result.commits) == (3, 2)
    assert result.lost == {"p.png": "bbb"}
    # Review Focus 5: nanoseconds and offsets give the exact instant
    dates = [datetime.fromisoformat(d).astimezone(UTC) for d in git(paths["git_dir"], "log", "--format=%cI").split()]
    assert dates == [datetime(2024, 12, 18, 8, 30, tzinfo=UTC), datetime(2024, 12, 17, 10, 0, 1, tzinfo=UTC)]
    messages = git(paths["git_dir"], "log", "--format=%s").splitlines()
    assert "ccc" in messages[0] and "aaa" in messages[1]


def test_head_matches_newest_snapshot(paths: dict[str, Path]) -> None:
    run_backfill(FakeRestic(SNAPSHOTS), paths)
    tree = git(paths["git_dir"], "ls-tree", "-r", "--name-only", "-z", "HEAD").split("\0")
    assert sorted(p for p in tree if p) == ["attachments.manifest", "n.md", "notes/Café.md"]
    assert git(paths["git_dir"], "show", "HEAD:n.md") == "2"
    assert git(paths["git_dir"], "show", "HEAD:attachments.manifest") == ""


def test_only_snapshots_and_restore_called(paths: dict[str, Path]) -> None:
    fake = FakeRestic(SNAPSHOTS)
    run_backfill(fake, paths)
    assert {c[0] for c in fake.calls} == {"snapshots", "restore"}


def test_restores_vault_subfolder_of_snapshot(paths: dict[str, Path]) -> None:
    # charlie snapshots /var/lib/obsidian/repo; the vault is its Get-Started folder
    nested = {sid: (t, {f"Get-Started/{rel}": c for rel, c in files.items()}) for sid, (t, files) in SNAPSHOTS.items()}
    fake = FakeRestic(nested)
    result = backfill(
        fake, SNAPSHOT_PATH, paths["git_dir"], paths["scratch"], EXCLUDE, paths["vault"],
        restore_path=f"{SNAPSHOT_PATH}/Get-Started",
    )  # fmt: skip
    assert fake.calls[0][:4] == ["snapshots", "--json", "--path", SNAPSHOT_PATH]
    assert result.lost == {"p.png": "bbb"}
    tree = git(paths["git_dir"], "ls-tree", "-r", "--name-only", "-z", "HEAD").split("\0")
    assert sorted(p for p in tree if p) == ["attachments.manifest", "n.md", "notes/Café.md"]


def test_restore_waits_for_restic_lock(paths: dict[str, Path]) -> None:
    # The hourly forget --prune holds an exclusive lock; restore must wait, not crash
    fake = FakeRestic(SNAPSHOTS)
    run_backfill(fake, paths)
    restores = [c for c in fake.calls if c[0] == "restore"]
    assert len(restores) == 3
    for call in restores:
        assert "--retry-lock" in call
        assert call[call.index("--retry-lock") + 1] == "30m"


def test_refuses_existing_git_dir(paths: dict[str, Path]) -> None:
    ensure_repo(paths["git_dir"], EXCLUDE)
    commit_snapshot(paths["git_dir"], paths["vault"], "", "m")
    with pytest.raises(ValueError):
        run_backfill(FakeRestic(SNAPSHOTS), paths)


@pytest.mark.parametrize("scratch", ["vault/x", "vault", "."])
def test_refuses_scratch_overlapping_vault(paths: dict[str, Path], scratch: str) -> None:
    base = paths["vault"].parent
    paths["scratch"] = (base / scratch.replace("vault", paths["vault"].name)).resolve()
    fake = FakeRestic(SNAPSHOTS)
    with pytest.raises(ValueError):
        run_backfill(fake, paths)
    assert fake.calls == []


def test_never_touches_vault(paths: dict[str, Path]) -> None:
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in paths["vault"].rglob("*")}
    run_backfill(FakeRestic(SNAPSHOTS), paths)
    after = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in paths["vault"].rglob("*")}
    assert before == after


def test_report_written(paths: dict[str, Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fake = FakeRestic(SNAPSHOTS)
    monkeypatch.setattr("backfill.Restic", lambda cmd: fake)
    report = tmp_path / "lost.tsv"
    rc = main(
        [
            "--restic", "restic-obsidian",
            "--snapshot-path", SNAPSHOT_PATH,
            "--git-dir", str(paths["git_dir"]),
            "--scratch", str(paths["scratch"]),
            "--exclude-file", str(EXCLUDE),
            "--vault", str(paths["vault"]),
            "--report", str(report),
        ]
    )  # fmt: skip
    assert rc == 0
    assert report.read_text() == "p.png\tbbb\n"
