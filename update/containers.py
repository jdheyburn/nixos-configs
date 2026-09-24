# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Update pinned OCI container image tags to the newest matching semver.

Lists tags with `skopeo`, selects the highest matching version, and rewrites
the `version = "…"` string in each target Nix module. Edits the working tree
only — never commits. Run from the repo root.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys

# skopeo is invoked via `nix run` by default so nothing needs pre-installing.
SKOPEO = shlex.split(os.environ.get("SKOPEO", "nix run nixpkgs#skopeo --"))

IMAGES = [
    {
        "name": "dashy",
        "ref": "docker://docker.io/lissy93/dashy",
        # dashy abandoned the release-X.Y.Z scheme at release-3.1.15 and now
        # publishes bare X.Y.Z tags; the module uses lissy93/dashy:${version}.
        "pattern": r"^(\d+)\.(\d+)\.(\d+)$",
        "file": "modules/nixos/dashy/default.nix",
        "to_file_version": lambda tag: tag,
    },
    {
        "name": "lubelogger",
        "ref": "docker://ghcr.io/hargata/lubelogger",
        # file stores a bare "1.7.0"; the module prepends the leading "v"
        "pattern": r"^v(\d+)\.(\d+)\.(\d+)$",
        "file": "modules/nixos/lubelogger/default.nix",
        "to_file_version": lambda tag: tag[1:],
    },
]


def select_latest(tags: list[str], pattern: str) -> str | None:
    """Return the tag with the highest (numeric) semver matching `pattern`."""
    rx = re.compile(pattern)
    best_tag: str | None = None
    best_key: tuple[int, ...] | None = None
    for tag in tags:
        m = rx.match(tag)
        if not m:
            continue
        key = tuple(int(g) for g in m.groups())
        if best_key is None or key > best_key:
            best_key, best_tag = key, tag
    return best_tag


def list_tags(ref: str) -> list[str]:
    out = subprocess.run(
        [*SKOPEO, "list-tags", ref],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out).get("Tags", [])


def current_version(path: str) -> str | None:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r'version\s*=\s*"([^"]*)"', text)
    return m.group(1) if m else None


def set_version(path: str, new_version: str) -> None:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    new_text = re.sub(
        r'(version\s*=\s*")[^"]*(")',
        lambda m: f"{m.group(1)}{new_version}{m.group(2)}",
        text, count=1,
    )
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true",
                    help="print old→new and write nothing")
    args = ap.parse_args()

    failures: list[str] = []
    for img in IMAGES:
        name = img["name"]
        try:
            tags = list_tags(img["ref"])
            winner = select_latest(tags, img["pattern"])
            if winner is None:
                raise RuntimeError(f"no tag matched {img['pattern']!r}")
            new_version = img["to_file_version"](winner)
            old_version = current_version(img["file"])
            if old_version == new_version:
                print(f"{name}: up to date ({old_version})")
                continue
            print(f"{name}: {old_version} -> {new_version}"
                  + (" (dry-run)" if args.dry_run else ""))
            if not args.dry_run:
                set_version(img["file"], new_version)
        except Exception as exc:  # keep going; report at the end
            print(f"{name}: ERROR {exc}", file=sys.stderr)
            failures.append(name)

    if failures:
        print(f"\nFailed: {', '.join(failures)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
