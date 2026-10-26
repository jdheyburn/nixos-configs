import os
import subprocess
import time

import pytest

from prune_worktrees import prune


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout


@pytest.fixture(autouse=True)
def git_env(monkeypatch):
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", "/dev/null")
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    for role in ("AUTHOR", "COMMITTER"):
        monkeypatch.setenv(f"GIT_{role}_NAME", "test")
        monkeypatch.setenv(f"GIT_{role}_EMAIL", "test@example.com")


@pytest.fixture
def repo(tmp_path):
    origin = tmp_path / "origin.git"
    git(tmp_path, "init", "-q", "--bare", "-b", "main", str(origin))
    clone = tmp_path / "code" / "r"
    git(tmp_path, "clone", "-q", str(origin), str(clone))
    (clone / "a.txt").write_text("a\n")
    git(clone, "add", "a.txt")
    git(clone, "commit", "-qm", "init")
    git(clone, "push", "-q", "origin", "main")
    return clone


def add_worktree(repo, name, branch=None):
    path = repo / ".claude" / "worktrees" / name
    if branch:
        git(repo, "worktree", "add", "-q", "-b", branch, str(path), "origin/main")
    else:
        git(repo, "worktree", "add", "-q", "--detach", str(path), "origin/main")
    return path


def commit(path, name="b.txt"):
    (path / name).write_text("b\n")
    git(path, "add", name)
    git(path, "commit", "-qm", f"add {name}")


def branches(repo):
    return git(repo, "branch", "--format=%(refname:short)").split()


def test_removes_pushed_worktree_and_its_branch(repo):
    wt = add_worktree(repo, "s1", "feature")
    commit(wt)
    git(wt, "push", "-q", "origin", "feature")
    assert prune(repo, min_age_days=0) == [wt]
    assert not wt.exists()
    assert "feature" not in branches(repo)


def test_removes_detached_worktree_with_nothing_new(repo):
    wt = add_worktree(repo, "s1")
    assert prune(repo, min_age_days=0) == [wt]
    assert not wt.exists()


def test_keeps_unpushed_commits(repo):
    wt = add_worktree(repo, "s1", "feature")
    commit(wt)
    assert prune(repo, min_age_days=0) == []
    assert wt.exists()
    assert "feature" in branches(repo)


@pytest.mark.parametrize("change", ["modified", "untracked"])
def test_keeps_local_changes(repo, change):
    wt = add_worktree(repo, "s1")
    (wt / ("a.txt" if change == "modified" else "new.txt")).write_text("x\n")
    assert prune(repo, min_age_days=0) == []
    assert wt.exists()


def test_removes_worktree_with_only_ignored_files(repo):
    wt = add_worktree(repo, "s1")
    (repo / ".git" / "info" / "exclude").write_text(".venv/\n")
    (wt / ".venv").mkdir()
    (wt / ".venv" / "x").write_text("x\n")
    assert prune(repo, min_age_days=0) == [wt]


def test_keeps_locked_worktree(repo):
    # The server locks a worktree while its session is live.
    wt = add_worktree(repo, "s1")
    git(repo, "worktree", "lock", "--reason", "claude agent s1 (pid 1)", str(wt))
    assert prune(repo, min_age_days=0) == []
    assert wt.exists()


def test_ignores_worktrees_outside_claude_dir(repo, tmp_path):
    # The server's own worktree at ~/rc/<name> must stay.
    rc = tmp_path / "rc" / "r"
    git(repo, "worktree", "add", "-q", "--detach", str(rc), "origin/main")
    assert prune(repo, min_age_days=0) == []
    assert rc.exists()


def test_keeps_commits_whose_remote_branch_was_deleted_unmerged(repo):
    wt = add_worktree(repo, "s1", "feature")
    commit(wt)
    git(wt, "push", "-q", "origin", "feature")
    git(wt, "push", "-q", "origin", "--delete", "feature")
    assert prune(repo, min_age_days=0) == []
    assert wt.exists()


def test_removes_branch_merged_into_main(repo):
    wt = add_worktree(repo, "s1", "feature")
    commit(wt)
    git(wt, "push", "-q", "origin", "feature:main")
    assert prune(repo, min_age_days=0) == [wt]


def test_fetch_failure_leaves_repo_alone(repo, tmp_path, capsys):
    wt = add_worktree(repo, "s1")
    git(repo, "remote", "set-url", "origin", str(tmp_path / "missing.git"))
    assert prune(repo, min_age_days=0) == []
    assert wt.exists()
    assert "fetch" in capsys.readouterr().err


def test_prunes_registrations_of_deleted_worktrees(repo):
    wt = add_worktree(repo, "s1")
    subprocess.run(["rm", "-rf", str(wt)], check=True)
    prune(repo, min_age_days=0)
    assert str(wt) not in git(repo, "worktree", "list")


def age(wt, days):
    # The signals prune reads: the worktree directory and its git admin files.
    when = time.time() - days * 86400
    gitdir = git(wt, "rev-parse", "--absolute-git-dir").strip()
    for p in [wt, *(os.path.join(gitdir, f) for f in ("HEAD", "index", "logs/HEAD"))]:
        if os.path.exists(p):
            os.utime(p, (when, when))


def test_keeps_worktree_touched_within_min_age(repo):
    # A deploy unlocks every worktree, including sessions Joe may reopen.
    wt = add_worktree(repo, "s1")
    age(wt, 6)
    assert prune(repo) == []
    assert wt.exists()


def test_removes_worktree_older_than_min_age(repo):
    wt = add_worktree(repo, "s1")
    age(wt, 8)
    assert prune(repo) == [wt]


def test_prune_does_not_refresh_age(repo):
    wt = add_worktree(repo, "s1")
    (wt / "a.txt").touch()  # stat change, so a plain git status would rewrite the index
    age(wt, 6)
    gitdir = git(wt, "rev-parse", "--absolute-git-dir").strip()
    before = os.stat(os.path.join(gitdir, "index")).st_mtime
    prune(repo)
    assert os.stat(os.path.join(gitdir, "index")).st_mtime == before
