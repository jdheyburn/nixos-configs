import containers


def test_select_latest_picks_highest_semver():
    tags = ["release-4.4.0", "release-4.5.0", "release-4.4.9", "latest", "dev"]
    pattern = r"^release-(\d+)\.(\d+)\.(\d+)$"
    assert containers.select_latest(tags, pattern) == "release-4.5.0"


def test_select_latest_ignores_non_matching_tags():
    tags = ["v1.7.0", "v1.10.0", "v1.7.1", "sha-abc123", "main"]
    pattern = r"^v(\d+)\.(\d+)\.(\d+)$"
    # numeric (not lexical) comparison: 1.10.0 > 1.7.1
    assert containers.select_latest(tags, pattern) == "v1.10.0"


def test_select_latest_returns_none_when_no_match():
    assert containers.select_latest(["latest", "dev"], r"^v(\d+)\.(\d+)\.(\d+)$") is None
