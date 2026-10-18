from pathlib import Path

import pytest

from vault import Reference, VaultIndex, build_manifest, find_references, list_files, missing_attachments


class Vault:
    def __init__(self, root: Path):
        self.root = root

    def __call__(self, files: dict[str, str | bytes]) -> None:
        for rel, content in files.items():
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(content, bytes):
                path.write_bytes(content)
            else:
                path.write_text(content, encoding="utf-8")


@pytest.fixture
def vault(tmp_path: Path) -> Vault:
    root = tmp_path / "vault"
    root.mkdir()
    return Vault(root)


@pytest.mark.parametrize(
    ("text", "targets"),
    [
        ("![[photo.png]]", ["photo.png"]),
        ("[[report.pdf|the report]]", ["report.pdf"]),
        ("![[scan.pdf#page=3]]", ["scan.pdf"]),
        ("![](attachments/My%20Image.png)", ["attachments/My Image.png"]),
        ('![alt](img/a.png "title")', ["img/a.png"]),
        # Review Focus 1: dotted note names are notes
        ("[[Release v1.2]] and [[Mr. Smith]]", []),
        # Review Focus 2: code is not a reference
        ("```\n![[x.png]]\n```\nand `![[y.png]]`", []),
        ("~~~\n![](z.png)\n~~~", []),
        ("![](https://example.com/a.png) [x](mailto:a@b.c)", []),
        ("[[Some note]] ![[diagram.canvas]]", []),
    ],
)
def test_find_references(text: str, targets: list[str]) -> None:
    assert [r.target for r in find_references("n.md", text)] == targets


def test_find_references_records_note() -> None:
    assert find_references("daily/d.md", "![[a.png]]") == [Reference("daily/d.md", "a.png")]


def test_resolve_by_basename_case_insensitive(vault: Vault) -> None:
    vault({"notes/attachments/photo.png": b"x"})
    idx = VaultIndex.from_dir(vault.root)
    assert idx.resolve(Reference("daily/d.md", "Photo.PNG")) == "notes/attachments/photo.png"


def test_resolve_markdown_relative_to_note(vault: Vault) -> None:
    vault({"notes/img/a.png": b"x", "img/a.png": b"y"})
    idx = VaultIndex.from_dir(vault.root)
    assert idx.resolve(Reference("notes/a.md", "img/a.png")) == "notes/img/a.png"


def test_resolve_markdown_falls_back_to_vault_root(vault: Vault) -> None:
    vault({"img/a.png": b"y"})
    idx = VaultIndex.from_dir(vault.root)
    assert idx.resolve(Reference("notes/a.md", "img/a.png")) == "img/a.png"


def test_resolve_missing(vault: Vault) -> None:
    vault({"a.png": b"x"})
    idx = VaultIndex.from_dir(vault.root)
    assert idx.resolve(Reference("n.md", "b.png")) is None


def test_resolve_ignores_trash(vault: Vault) -> None:
    vault({".trash/a.png": b"x"})
    idx = VaultIndex.from_dir(vault.root)
    assert idx.resolve(Reference("n.md", "a.png")) is None


def test_missing_attachments_respects_ignore(vault: Vault) -> None:
    vault({"a.md": "![[gone.png]] ![[kept.png]] ![[old.png]]", "kept.png": b"x"})
    assert [r.target for r in missing_attachments(vault.root, {"old.png"})] == ["gone.png"]


def test_missing_attachments_skips_obsidian_and_trash_notes(vault: Vault) -> None:
    vault({".trash/a.md": "![[gone.png]]", ".obsidian/b.md": "![[gone.png]]"})
    assert missing_attachments(vault.root, set()) == []


def test_missing_attachments_sorted(vault: Vault) -> None:
    vault({"b.md": "![[z.png]]", "a.md": "![[y.png]] ![[x.png]]"})
    assert missing_attachments(vault.root, set()) == [
        Reference("a.md", "x.png"),
        Reference("a.md", "y.png"),
        Reference("b.md", "z.png"),
    ]


def test_build_manifest(vault: Vault) -> None:
    # Review Focus 4: spaces and non-ASCII in paths
    vault(
        {
            "n.md": "x",
            "c.canvas": "{}",
            "notes/attachments/Café menu.png": b"abc",
            ".obsidian/app.json": "{}",
            ".trash/t.png": b"z",
        }
    )
    assert build_manifest(vault.root) == (
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\t3\tnotes/attachments/Café menu.png\n"
    )


def test_build_manifest_empty(vault: Vault) -> None:
    vault({"n.md": "x"})
    assert build_manifest(vault.root) == ""


def test_nested_git_dir_is_ignored(vault: Vault) -> None:
    vault({"n.md": "x", ".git/objects/ab/cdef": b"blob", ".git/HEAD": "ref"})
    assert list_files(vault.root) == ["n.md"]
    assert build_manifest(vault.root) == ""


def test_list_files(vault: Vault) -> None:
    vault({"b.md": "x", "a/c.png": b"x", ".obsidian/app.json": "{}", ".trash/t.md": "x"})
    assert list_files(vault.root) == [".obsidian/app.json", "a/c.png", "b.md"]
