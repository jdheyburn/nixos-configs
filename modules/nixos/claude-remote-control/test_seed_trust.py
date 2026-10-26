import json
import os
import stat

import pytest

from seed_trust import seed_trust


def test_creates_missing_file(tmp_path):
    p = tmp_path / ".claude.json"
    seed_trust(p, ["/var/lib/claude-remote-control/code/nixos-configs"])
    data = json.loads(p.read_text())
    assert data["projects"]["/var/lib/claude-remote-control/code/nixos-configs"]["hasTrustDialogAccepted"] is True
    assert stat.S_IMODE(os.stat(p).st_mode) == 0o600


def test_empty_file_treated_as_empty_object(tmp_path):
    p = tmp_path / ".claude.json"
    p.write_text("")
    seed_trust(p, ["/a"])
    assert json.loads(p.read_text()) == {
        "projects": {"/a": {"hasTrustDialogAccepted": True}},
        "remoteDialogSeen": True,
    }


def test_keeps_unrelated_keys(tmp_path):
    p = tmp_path / ".claude.json"
    p.write_text(json.dumps({"oauthAccount": {"x": 1}, "projects": {"/a": {"allowedTools": ["Bash"]}, "/b": {"y": 2}}}))
    seed_trust(p, ["/a"])
    data = json.loads(p.read_text())
    assert data["oauthAccount"] == {"x": 1}
    assert data["projects"]["/a"] == {"allowedTools": ["Bash"], "hasTrustDialogAccepted": True}
    assert data["projects"]["/b"] == {"y": 2}


def test_marks_remote_control_prompt_seen(tmp_path):
    # Without it, `claude remote-control` waits at "Enable Remote Control? (y/n)".
    p = tmp_path / ".claude.json"
    p.write_text(json.dumps({"remoteDialogSeen": False, "oauthAccount": {"x": 1}}))
    seed_trust(p, ["/a"])
    data = json.loads(p.read_text())
    assert data["remoteDialogSeen"] is True
    assert data["oauthAccount"] == {"x": 1}


@pytest.mark.parametrize("dirs", [["/a"], ["/a", "/b"]])
def test_idempotent(tmp_path, dirs):
    p = tmp_path / ".claude.json"
    seed_trust(p, dirs)
    first = p.read_text()
    seed_trust(p, dirs)
    assert p.read_text() == first


def test_invalid_json_left_untouched(tmp_path, capsys):
    # A failure here would stop the service and keep every server down, so
    # warn and leave the file to Claude Code.
    p = tmp_path / ".claude.json"
    p.write_text("{not json")
    seed_trust(p, ["/a"])
    assert p.read_text() == "{not json"
    assert "not valid JSON" in capsys.readouterr().err
