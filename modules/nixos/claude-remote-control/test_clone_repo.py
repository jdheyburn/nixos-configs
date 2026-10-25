import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parent / "clone_repo.sh"

# Stands in for git: fails until it has been called FAKE_GIT_FAILS + 1
# times, then creates DEST/.git. Each call's arguments are logged.
FAKE_GIT = """#!/usr/bin/env bash
echo "$*" >> "$FAKE_GIT_LOG"
calls=$(wc -l < "$FAKE_GIT_LOG")
if [ "$calls" -le "$FAKE_GIT_FAILS" ]; then
  echo "fatal: Could not resolve host: github.com" >&2
  exit 128
fi
mkdir -p "$3/.git"
"""


@pytest.fixture
def run(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    git = bin_dir / "git"
    git.write_text(FAKE_GIT)
    git.chmod(0o755)
    log = tmp_path / "git.log"
    log.touch()
    dest = tmp_path / "code" / "repo"

    def _run(fails, attempts=3):
        env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "FAKE_GIT_LOG": str(log),
            "FAKE_GIT_FAILS": str(fails),
        }
        result = subprocess.run(
            ["bash", str(SCRIPT), "https://github.com/o/r.git", str(dest), str(attempts), "0"],
            env=env,
            capture_output=True,
            text=True,
        )
        return result, log.read_text().splitlines(), dest

    return _run


def test_clones_on_first_try(run):
    result, calls, dest = run(fails=0)
    assert result.returncode == 0
    assert calls == [f"clone https://github.com/o/r.git {dest}"]
    assert (dest / ".git").is_dir()


def test_retries_until_clone_succeeds(run):
    result, calls, dest = run(fails=2)
    assert result.returncode == 0
    assert len(calls) == 3
    assert (dest / ".git").is_dir()


def test_gives_up_after_attempts(run):
    result, calls, dest = run(fails=99, attempts=3)
    assert result.returncode != 0
    assert len(calls) == 3
    assert not dest.exists()
