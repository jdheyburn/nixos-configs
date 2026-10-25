"""Mark directories as trusted in Claude Code's ~/.claude.json.

`claude remote-control` exits with "Workspace not trusted" until someone
answers the trust prompt in a terminal. Setting
projects["<dir>"].hasTrustDialogAccepted ahead of time skips that prompt.
The file also holds Claude Code's own state, so every other key is kept.
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path


def seed_trust(claude_json: Path, dirs: list[str]) -> None:
    text = claude_json.read_text() if claude_json.exists() else ""
    try:
        data = json.loads(text) if text.strip() else {}
    except json.JSONDecodeError as e:
        sys.exit(f"{claude_json}: not valid JSON, leaving it alone: {e}")

    projects = data.setdefault("projects", {})
    for d in dirs:
        projects.setdefault(d, {})["hasTrustDialogAccepted"] = True

    fd, tmp = tempfile.mkstemp(dir=claude_json.parent, prefix=".claude.json.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, claude_json)
    except BaseException:
        os.unlink(tmp)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--claude-json", type=Path, required=True)
    parser.add_argument("--dir", action="append", required=True, dest="dirs")
    args = parser.parse_args()
    seed_trust(args.claude_json, args.dirs)


if __name__ == "__main__":
    main()
