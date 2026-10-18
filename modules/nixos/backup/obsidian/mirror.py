# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Alert when charlie's obsidian-headless mirror stops syncing.

`ob sync --continuous` logs "Fully synced" every 30 seconds while connected
and up to date, and "Downloaded <path>" while catching up. It logs neither
while disconnected or stuck reconnecting. Pings healthchecks with success
when the newest of those lines is recent, /fail otherwise.
"""

from __future__ import annotations

import argparse
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

from history import ping_healthcheck

# Enough for several minutes of a download burst
TAIL_BYTES = 256 * 1024
HEARTBEAT = re.compile(r"^\[(\S+)\] (?:Fully synced$|Downloaded )")


def _last_in_log(log: Path) -> datetime | None:
    with log.open("rb") as f:
        f.seek(max(0, f.seek(0, 2) - TAIL_BYTES))
        lines = f.read().decode("utf-8", errors="replace").splitlines()
    for line in reversed(lines):
        if match := HEARTBEAT.match(line):
            return datetime.fromisoformat(match[1])
    return None


def last_synced(state_dir: Path) -> datetime | None:
    """Newest heartbeat across every vault's sync.log under `state_dir`."""
    found = [t for log in state_dir.glob("*/sync.log") if (t := _last_in_log(log)) is not None]
    return max(found, default=None)


def is_fresh(last: datetime | None, now: datetime, max_age: timedelta) -> bool:
    return last is not None and now - last <= max_age


def main(argv: list[str] | None = None, now: datetime | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, required=True, help="obsidian-headless sync state directory")
    parser.add_argument("--healthcheck", required=True)
    parser.add_argument("--max-age-minutes", type=int, default=15)
    args = parser.parse_args(argv)

    now = now or datetime.now(UTC)
    last = last_synced(args.state_dir)
    if last is None:
        body = f"no sync heartbeat under {args.state_dir}\n"
    else:
        body = f"last synced {last:%Y-%m-%dT%H:%M:%SZ}, {int((now - last).total_seconds() // 60)} min ago\n"
    print(body, end="")
    ping_healthcheck(args.healthcheck, is_fresh(last, now, timedelta(minutes=args.max_age_minutes)), body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
