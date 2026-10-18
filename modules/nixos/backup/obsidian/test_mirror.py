from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

import mirror
from mirror import is_fresh, last_synced, main

URL = "https://healthchecks.example/ping/def"
NOW = datetime(2026, 10, 18, 13, 0, tzinfo=UTC)

SYNCED = """\
[2026-10-18T12:46:32.308Z] Fully synced
[2026-10-18T12:47:02.306Z] Fully synced
"""


def write_log(state_dir: Path, vault_id: str, text: str) -> Path:
    log = state_dir / vault_id / "sync.log"
    log.parent.mkdir(parents=True)
    log.write_text(text)
    return log


@pytest.fixture
def state_dir(tmp_path: Path) -> Path:
    return tmp_path / "sync"


@pytest.fixture
def pings(monkeypatch: pytest.MonkeyPatch) -> list[tuple[str, bool, str]]:
    calls: list[tuple[str, bool, str]] = []
    monkeypatch.setattr(mirror, "ping_healthcheck", lambda url, ok, body: calls.append((url, ok, body)))
    return calls


def run_main(state_dir: Path, now: datetime = NOW) -> int:
    return main(["--state-dir", str(state_dir), "--healthcheck", URL, "--max-age-minutes", "15"], now=now)


def test_last_synced_reads_newest_heartbeat(state_dir: Path) -> None:
    write_log(state_dir, "v1", SYNCED)
    assert last_synced(state_dir) == datetime(2026, 10, 18, 12, 47, 2, 306000, tzinfo=UTC)


def test_reconnect_loop_is_not_a_heartbeat(state_dir: Path) -> None:
    # Seen at 12:47 on charlie: no "Fully synced" while disconnected
    write_log(
        state_dir,
        "v1",
        SYNCED
        + "[2026-10-18T12:47:23.166Z] Disconnected from server\n"
        + "[2026-10-18T12:47:23.166Z] Waiting to connect to server\n"
        + "[2026-10-18T12:59:32.305Z] Connecting...\n",
    )
    assert last_synced(state_dir) == datetime(2026, 10, 18, 12, 47, 2, 306000, tzinfo=UTC)


def test_download_burst_counts_as_alive(state_dir: Path) -> None:
    # The first sync downloads for minutes without a "Fully synced" line
    burst = "".join(
        f"[2026-10-18T12:59:{s:02d}.000Z] Downloading notes/n{s}.md\n"
        f"[2026-10-18T12:59:{s:02d}.100Z] Downloaded notes/n{s}.md\n"
        f"[2026-10-18T12:59:{s:02d}.200Z] Accepted notes/n{s}.md\n"
        for s in range(60)
    )
    write_log(state_dir, "v1", SYNCED + burst * 50)
    assert last_synced(state_dir) == datetime(2026, 10, 18, 12, 59, 59, 100000, tzinfo=UTC)


def test_untimestamped_lines_ignored(state_dir: Path) -> None:
    write_log(state_dir, "v1", SYNCED + "Received signal to shut down...\nFully synced\n")
    assert last_synced(state_dir) == datetime(2026, 10, 18, 12, 47, 2, 306000, tzinfo=UTC)


def test_newest_vault_log_wins(state_dir: Path) -> None:
    # A vault re-set-up under a new id leaves the old log behind
    write_log(state_dir, "old", "[2026-01-01T00:00:00.000Z] Fully synced\n")
    write_log(state_dir, "new", SYNCED)
    assert last_synced(state_dir) == datetime(2026, 10, 18, 12, 47, 2, 306000, tzinfo=UTC)


@pytest.mark.parametrize("text", ["", "[2026-10-18T12:47:23.166Z] Connecting...\n"])
def test_no_heartbeat(state_dir: Path, text: str) -> None:
    write_log(state_dir, "v1", text)
    assert last_synced(state_dir) is None


def test_no_state_dir(state_dir: Path) -> None:
    assert last_synced(state_dir) is None


@pytest.mark.parametrize(
    ("age", "fresh"),
    [(timedelta(minutes=1), True), (timedelta(minutes=15), True), (timedelta(minutes=15, seconds=1), False)],
)
def test_is_fresh(age: timedelta, fresh: bool) -> None:
    assert is_fresh(NOW - age, NOW, timedelta(minutes=15)) is fresh


def test_is_fresh_none() -> None:
    assert is_fresh(None, NOW, timedelta(minutes=15)) is False


def test_main_pings_ok_when_fresh(state_dir: Path, pings: list) -> None:
    write_log(state_dir, "v1", SYNCED)
    assert run_main(state_dir) == 0
    assert pings == [(URL, True, "last synced 2026-10-18T12:47:02Z, 12 min ago\n")]


def test_main_pings_fail_when_stale(state_dir: Path, pings: list) -> None:
    write_log(state_dir, "v1", SYNCED)
    assert run_main(state_dir, now=NOW + timedelta(hours=1)) == 0
    assert pings == [(URL, False, "last synced 2026-10-18T12:47:02Z, 72 min ago\n")]


def test_main_pings_fail_without_log(state_dir: Path, pings: list) -> None:
    assert run_main(state_dir) == 0
    assert pings == [(URL, False, f"no sync heartbeat under {state_dir}\n")]
