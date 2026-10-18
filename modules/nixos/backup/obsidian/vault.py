# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Scan an Obsidian vault for attachment references and attachment files.

Used by history.py (hourly check and manifest) and backfill.py (manifest per
restic snapshot). Standard library only: it runs on charlie from the Nix store.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from urllib.parse import unquote

# File types Obsidian treats as attachments.
ATTACHMENT_EXTENSIONS = frozenset(
    "png jpg jpeg gif bmp svg webp avif mp3 wav m4a ogg 3gp flac webm mp4 ogv mov mkv pdf".split()
)
NOTE_EXTENSIONS = frozenset({"md", "canvas", "base"})

# Top-level folders that never hold live notes or attachments.
SKIPPED_DIRS = frozenset({".trash", ".git"})
CONFIG_DIR = ".obsidian"

_FENCED_CODE = re.compile(r"^(```|~~~).*?^\1[^\n]*$", re.MULTILINE | re.DOTALL)
_INLINE_CODE = re.compile(r"`[^`\n]*`")
_WIKILINK = re.compile(r"!?\[\[([^\]]+)\]\]")
_MARKDOWN_LINK = re.compile(r'!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
_SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


@dataclass(frozen=True)
class Reference:
    note: str
    target: str


def _extension(path: str) -> str:
    return PurePosixPath(path).suffix.lower().lstrip(".")


def _is_attachment_target(target: str) -> bool:
    return _extension(target) in ATTACHMENT_EXTENSIONS


def find_references(note: str, text: str) -> list[Reference]:
    """Return the attachment references in a note's text, in order."""
    text = _FENCED_CODE.sub("", text)
    text = _INLINE_CODE.sub("", text)
    matches: list[tuple[int, str]] = []
    for m in _WIKILINK.finditer(text):
        target = re.split(r"[#^]", m.group(1).split("|", 1)[0], maxsplit=1)[0].strip()
        matches.append((m.start(), target))
    for m in _MARKDOWN_LINK.finditer(text):
        raw = m.group(1)
        if _SCHEME.match(raw):
            continue
        target = unquote(raw.split("#", 1)[0]).strip()
        matches.append((m.start(), target))
    return [Reference(note, t) for _, t in sorted(matches) if t and _is_attachment_target(t)]


def _walk(root: Path) -> list[str]:
    files = []
    for path in root.rglob("*"):
        rel = path.relative_to(root)
        if rel.parts[0] in SKIPPED_DIRS or not path.is_file():
            continue
        files.append(rel.as_posix())
    return sorted(files)


def list_files(root: Path) -> list[str]:
    """Every regular file in the vault outside .trash/, vault-relative, sorted."""
    return _walk(root)


class VaultIndex:
    def __init__(self, paths: list[str]):
        self.paths = set(paths)
        self._by_lower_path = {p.lower(): p for p in sorted(paths)}
        self._by_lower_name: dict[str, str] = {}
        for p in sorted(paths):
            self._by_lower_name.setdefault(PurePosixPath(p).name.lower(), p)

    @classmethod
    def from_dir(cls, root: Path) -> VaultIndex:
        return cls(_walk(root))

    def resolve(self, ref: Reference) -> str | None:
        """Return the vault-relative path a reference points at, or None."""
        target = ref.target.lstrip("/")
        if "/" in target:
            note_dir = PurePosixPath(ref.note).parent
            for candidate in (note_dir / target, PurePosixPath(target)):
                found = self._by_lower_path.get(_normalise(candidate).lower())
                if found:
                    return found
        return self._by_lower_name.get(PurePosixPath(target).name.lower())


def _normalise(path: PurePosixPath) -> str:
    parts: list[str] = []
    for part in path.parts:
        if part == "..":
            if parts:
                parts.pop()
        elif part not in (".", ""):
            parts.append(part)
    return "/".join(parts)


def _notes(files: list[str]) -> list[str]:
    return [f for f in files if _extension(f) == "md" and not f.startswith(CONFIG_DIR + "/")]


def missing_attachments(root: Path, ignored: set[str]) -> list[Reference]:
    """References to attachments that don't exist, minus ignored targets."""
    files = _walk(root)
    index = VaultIndex(files)
    missing = set()
    for note in _notes(files):
        text = (root / note).read_text(encoding="utf-8", errors="replace")
        for ref in find_references(note, text):
            if ref.target not in ignored and index.resolve(ref) is None:
                missing.add(ref)
    return sorted(missing, key=lambda r: (r.note, r.target))


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def build_manifest(root: Path) -> str:
    """One "<sha256>\\t<size>\\t<path>" line per attachment, sorted by path."""
    lines = []
    for rel in _walk(root):
        if rel.startswith(CONFIG_DIR + "/") or _extension(rel) in NOTE_EXTENSIONS:
            continue
        path = root / rel
        lines.append(f"{_sha256(path)}\t{path.stat().st_size}\t{rel}\n")
    return "".join(lines)
