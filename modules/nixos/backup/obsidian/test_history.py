import subprocess
from datetime import UTC, datetime
from pathlib import Path

import pytest

import history
from history import commit_snapshot, ensure_repo, main
from test_vault import Vault

EXCLUDE = Path(__file__).parent / "vault-exclude"
URL = "https://healthchecks.example/ping/abc"


@pytest.fixture
def vault(tmp_path: Path) -> Vault:
    root = tmp_path / "vault"
    root.mkdir()
    return Vault(root)


@pytest.fixture
def git_dir(tmp_path: Path) -> Path:
    return tmp_path / "history.git"


@pytest.fixture
def pings(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, bool, str]]:
    calls: list[tuple[str, bool, str]] = []
    monkeypatch.setattr(history, "ping_healthcheck", lambda url, ok, body: calls.append((url, ok, body)))
    return calls


def git(git_dir: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "--git-dir", str(git_dir), *args], check=True, capture_output=True, text=True
    ).stdout


def ls_tree(git_dir: Path) -> list[str]:
    out = git(git_dir, "ls-tree", "-r", "--name-only", "-z", "HEAD")
    return [p for p in out.split("\0") if p]


def run_main(vault: Vault, git_dir: Path, tmp_path: Path, ignored: str | None = "") -> int:
    ignore_file = tmp_path / "ignored"
    if ignored is not None:
        ignore_file.write_text(ignored)
    return main(
        [
            "--vault", str(vault.root),
            "--git-dir", str(git_dir),
            "--exclude-file", str(EXCLUDE),
            "--ignore-file", str(ignore_file),
            "--healthcheck", URL,
        ]
    )  # fmt: skip


def test_tracks_notes_and_settings_not_attachments(vault: Vault, git_dir: Path) -> None:
    vault(
        {
            "n.md": "x",
            "c.canvas": "{}",
            "img.png": b"x",
            ".obsidian/app.json": "{}",
            ".obsidian/workspace.json": "{}",
            ".obsidian/plugins/p/manifest.json": "{}",
            ".obsidian/plugins/p/data.json": "{}",
            ".obsidian/plugins/p/main.js": "",
            ".obsidian/themes/t/theme.css": "",
            ".trash/old.md": "x",
        }
    )
    ensure_repo(git_dir, EXCLUDE)
    assert commit_snapshot(git_dir, vault.root, "", "m") is True
    assert ls_tree(git_dir) == [
        ".obsidian/app.json",
        ".obsidian/plugins/p/data.json",
        ".obsidian/plugins/p/manifest.json",
        "attachments.manifest",
        "c.canvas",
        "n.md",
    ]


def test_ensure_repo_is_bare_and_shared(git_dir: Path) -> None:
    ensure_repo(git_dir, EXCLUDE)
    assert git(git_dir, "rev-parse", "--is-bare-repository").strip() == "true"
    assert git(git_dir, "config", "core.sharedRepository").strip() in {"group", "1"}
    assert (git_dir / "info" / "exclude").read_text() == EXCLUDE.read_text()


def test_no_commit_when_unchanged(vault: Vault, git_dir: Path) -> None:
    vault({"n.md": "x"})
    ensure_repo(git_dir, EXCLUDE)
    assert commit_snapshot(git_dir, vault.root, "", "m") is True
    assert commit_snapshot(git_dir, vault.root, "", "m") is False
    assert git(git_dir, "rev-list", "--count", "HEAD").strip() == "1"


def test_commits_deletions(vault: Vault, git_dir: Path) -> None:
    vault({"a.md": "x", "b.md": "y"})
    ensure_repo(git_dir, EXCLUDE)
    commit_snapshot(git_dir, vault.root, "", "m")
    (vault.root / "b.md").unlink()
    assert commit_snapshot(git_dir, vault.root, "", "m") is True
    assert ls_tree(git_dir) == ["a.md", "attachments.manifest"]


def test_manifest_change_alone_commits(vault: Vault, git_dir: Path) -> None:
    vault({"n.md": "x"})
    ensure_repo(git_dir, EXCLUDE)
    commit_snapshot(git_dir, vault.root, "", "m")
    assert commit_snapshot(git_dir, vault.root, "abc\t1\tp.png\n", "m") is True
    assert git(git_dir, "show", "HEAD:attachments.manifest") == "abc\t1\tp.png\n"


def test_manifest_not_written_into_vault(vault: Vault, git_dir: Path) -> None:
    vault({"n.md": "x"})
    ensure_repo(git_dir, EXCLUDE)
    commit_snapshot(git_dir, vault.root, "abc\t1\tp.png\n", "m")
    assert not (vault.root / "attachments.manifest").exists()


def test_commit_date(vault: Vault, git_dir: Path) -> None:
    vault({"n.md": "x"})
    ensure_repo(git_dir, EXCLUDE)
    when = datetime(2024, 12, 17, 10, 0, 1, tzinfo=UTC)
    commit_snapshot(git_dir, vault.root, "", "m", when=when)
    dates = git(git_dir, "log", "-1", "--format=%aI%n%cI").split()
    assert [datetime.fromisoformat(d) for d in dates] == [when, when]


def test_main_pings_fail_with_missing_list(vault: Vault, git_dir: Path, tmp_path: Path, pings: list) -> None:
    vault({"a.md": "![[gone.png]]"})
    assert run_main(vault, git_dir, tmp_path) == 0
    assert pings == [(URL, False, "a.md: gone.png\n")]


def test_main_respects_ignore_file(vault: Vault, git_dir: Path, tmp_path: Path, pings: list) -> None:
    vault({"a.md": "![[gone.png]] ![[old.png]]"})
    run_main(vault, git_dir, tmp_path, ignored="old.png\n\n")
    assert pings == [(URL, False, "a.md: gone.png\n")]


def test_main_without_ignore_file(vault: Vault, git_dir: Path, tmp_path: Path, pings: list) -> None:
    # The ignore file lives on the host, outside the repo, and may not exist yet
    vault({"a.md": "![[gone.png]]"})
    assert run_main(vault, git_dir, tmp_path, ignored=None) == 0
    assert pings == [(URL, False, "a.md: gone.png\n")]


def test_main_pings_ok_when_nothing_missing(vault: Vault, git_dir: Path, tmp_path: Path, pings: list) -> None:
    vault({"a.md": "![[here.png]]", "here.png": b"x"})
    assert run_main(vault, git_dir, tmp_path) == 0
    assert pings == [(URL, True, "")]
    assert "here.png" in git(git_dir, "show", "HEAD:attachments.manifest")


def test_main_unicode_paths(vault: Vault, git_dir: Path, tmp_path: Path, pings: list) -> None:
    # Review Focus 4
    vault({"notes/Café.md": "![[Café menu.png]]", "notes/attachments/Café menu.png": b"x"})
    run_main(vault, git_dir, tmp_path)
    assert pings == [(URL, True, "")]
    assert "notes/Café.md" in ls_tree(git_dir)
