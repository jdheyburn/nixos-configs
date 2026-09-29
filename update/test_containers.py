import pytest

import containers


def pattern_for(name: str) -> str:
    """Return the tag pattern configured for `name` in containers.IMAGES."""
    return next(img["pattern"] for img in containers.IMAGES if img["name"] == name)


@pytest.mark.parametrize(
    ("name", "tags", "expected"),
    [
        # numeric (not lexical) comparison: 4.7.10 > 4.7.9; floating and
        # legacy release-X.Y.Z tags are ignored
        ("dashy", ["4.7.9", "4.7.10", "4.x", "4.7", "latest", "release-4.5.0"], "4.7.10"),
        ("lubelogger", ["v1.7.0", "v1.10.0", "v1.7.1", "sha-abc123", "main"], "v1.10.0"),
        ("lubelogger", ["latest", "dev"], None),
    ],
)
def test_select_latest(name, tags, expected):
    assert containers.select_latest(tags, pattern_for(name)) == expected


@pytest.mark.parametrize(
    ("name", "tag", "file_version"),
    [
        ("dashy", "4.7.10", "4.7.10"),
        ("lubelogger", "v1.7.3", "1.7.3"),
    ],
)
def test_to_file_version(name, tag, file_version):
    img = next(img for img in containers.IMAGES if img["name"] == name)
    assert img["to_file_version"](tag) == file_version
