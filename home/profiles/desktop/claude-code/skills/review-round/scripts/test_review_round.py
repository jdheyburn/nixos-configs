# Run: uv run --with pytest pytest <this dir>
import pytest
from review_round import (
    ACTIVE_WINDOW,
    NO_PR_IDLE,
    cluster_decision,
    parse_memory,
    parse_worktrees,
    pr_from_names,
    project_slug,
    review_status,
    thread_replies,
    worktree_decision,
)

ME = "me"
NOW = 1_800_000_000.0


def user(name):
    return {"login": name, "__typename": "User"}


def bot(name):
    return {"login": name, "__typename": "Bot"}


def comment(author, at, url="u"):
    return {"author": author, "createdAt": at, "url": url}


def make_pr(head="bbbbbbb", reviews=(), threads=(), comments=(), requested=()):
    return {
        "headRefOid": head,
        "reviews": {"nodes": list(reviews)},
        "reviewThreads": {"nodes": list(threads)},
        "comments": {"nodes": list(comments)},
        "reviewRequests": {"nodes": [{"requestedReviewer": {"login": r}} for r in requested]},
    }


def review(state, at, oid="aaaaaaa", author=ME):
    return {"author": user(author), "state": state, "submittedAt": at, "commit": {"oid": oid} if oid else None}


def thread(*comments, resolved=False, path="f.go"):
    return {"isResolved": resolved, "path": path, "comments": {"nodes": list(comments)}}


def test_parse_worktrees():
    porcelain = (
        "worktree /r\nHEAD 111\nbranch refs/heads/main\n\n"
        "worktree /r/.worktrees/pr-1-review\nHEAD 222\ndetached\n\n"
        "worktree /r/.worktrees/x\nHEAD 333\nbranch refs/heads/me/fix/x\n"
    )
    assert parse_worktrees(porcelain) == [
        {"path": "/r", "head": "111", "branch": "main"},
        {"path": "/r/.worktrees/pr-1-review", "head": "222", "branch": None},
        {"path": "/r/.worktrees/x", "head": "333", "branch": "me/fix/x"},
    ]


@pytest.mark.parametrize(
    ("names", "expected"),
    [
        (("/r/.worktrees/pr-490-review", None), 490),
        (("/r/.worktrees/pr-410", None), 410),
        (("/r/.worktrees/review-x", "pr-203-review"), 203),
        (("/r/.worktrees/fix-545-service-account", "me/fix/x"), None),
        (("/r/.worktrees/project-1", None), None),
    ],
)
def test_pr_from_names(names, expected):
    assert pr_from_names(*names) == expected


def test_project_slug():
    path = "/Users/a.b/code/valkey-operator_x/.worktrees/pr-1"
    assert project_slug(path) == "-Users-a-b-code-valkey-operator-x--worktrees-pr-1"


def test_parse_memory_prefers_description_sha_and_skips_worktree_paths():
    text = (
        "---\nname: x\n"
        'description: "PR #490 kind-reviewed 2026-10-08 at 397921d; round 2 at 8e46a6a"\n---\n'
        "First pass at 1234567. kind `pr-490-review` and worktree `.worktrees/pr-491-review` left running.\n"
    )
    mem = parse_memory("project_pr490_review.md", text)
    assert mem == {
        "pr": 490,
        "file": "project_pr490_review.md",
        "reviewedSha": "8e46a6a",
        "clusters": ["pr-490-review"],
    }


def test_parse_memory_ignores_other_files():
    assert parse_memory("project_scheduling_epic.md", "") is None


def test_thread_replies_counts_humans_after_my_last_comment():
    pr = make_pr(
        threads=[
            thread(comment(user(ME), "2026-01-01T00:00:00Z"), comment(user("author"), "2026-01-02T00:00:00Z", "r1")),
            thread(comment(user("author"), "2026-01-01T00:00:00Z"), comment(user(ME), "2026-01-02T00:00:00Z")),
            thread(comment(user(ME), "2026-01-01T00:00:00Z"), comment(bot("greptile"), "2026-01-02T00:00:00Z")),
            thread(comment(user("other"), "2026-01-01T00:00:00Z"), comment(user("author"), "2026-01-02T00:00:00Z")),
        ]
    )
    assert thread_replies(pr, ME) == [{"path": "f.go", "by": "author", "url": "r1", "resolved": False}]


def test_first_review_when_never_reviewed():
    st = review_status(make_pr(requested=[ME]), ME, None)
    assert st["bucket"] == "first-review"
    assert st["reasons"] == []


def test_waiting_when_nothing_happened_since_review():
    pr = make_pr(head="aaaaaaa1", reviews=[review("CHANGES_REQUESTED", "2026-01-01T00:00:00Z", "aaaaaaa1")])
    st = review_status(pr, ME, None)
    assert st["bucket"] == "waiting"
    assert st["lastState"] == "CHANGES_REQUESTED"


@pytest.mark.parametrize(
    ("pr", "reasons"),
    [
        (
            make_pr(head="bbbbbbb", reviews=[review("COMMENTED", "2026-01-01T00:00:00Z", "aaaaaaa")]),
            ["new head"],
        ),
        (
            make_pr(head="aaaaaaa", reviews=[review("COMMENTED", "2026-01-01T00:00:00Z")], requested=[ME]),
            ["re-requested"],
        ),
        (
            make_pr(
                head="aaaaaaa",
                reviews=[review("COMMENTED", "2026-01-01T00:00:00Z")],
                comments=[
                    comment(user("author"), "2026-01-02T00:00:00Z"),
                    comment(user("author"), "2025-12-31T00:00:00Z"),
                    comment(bot("ci"), "2026-01-02T00:00:00Z"),
                ],
            ),
            ["1 new comment"],
        ),
    ],
    ids=["new-head", "re-requested", "new-comment"],
)
def test_round_due(pr, reasons):
    st = review_status(pr, ME, None)
    assert st["bucket"] == "round-due"
    assert st["reasons"] == reasons


def test_force_pushed_review_commit_counts_as_new_head():
    pr = make_pr(head="ccccccc", reviews=[review("COMMENTED", "2026-01-01T00:00:00Z", oid=None)])
    st = review_status(pr, ME, {"reviewedSha": "aaaaaaa"})
    assert st["bucket"] == "round-due"
    assert st["reviewedCommitGone"]
    assert st["reviewedSha"] == "aaaaaaa"


def test_memory_sha_stands_in_without_a_github_review():
    st = review_status(make_pr(head="aaaaaaa123"), ME, {"reviewedSha": "aaaaaaa"})
    assert st["bucket"] == "waiting"
    assert st["lastState"] is None


def test_pending_review_is_a_draft_not_a_review():
    pr = make_pr(reviews=[review("PENDING", None)])
    st = review_status(pr, ME, None)
    assert st["bucket"] == "first-review"
    assert st["pendingDraft"]


def wt(**overrides):
    return {"dirty": False, "op": None, "inUse": False, "lastActive": NOW - 30 * 86400, "unpushed": [], **overrides}


@pytest.mark.parametrize(
    ("worktree", "pr_state", "expected"),
    [
        (wt(), "MERGED", (True, "PR merged")),
        (wt(), "CLOSED", (True, "PR closed")),
        (wt(), "OPEN", (False, "open PR")),
        (wt(), None, (True, "no PR, idle 14 days, nothing of yours unpushed")),
        (wt(lastActive=NOW - NO_PR_IDLE + 60), None, (False, "no PR, active in the last 14 days")),
        (wt(dirty=True), "MERGED", (False, "uncommitted or untracked files")),
        (wt(op="merge"), "MERGED", (False, "merge in progress")),
        (wt(inUse=True), "MERGED", (False, "a process is running in it")),
        (wt(lastActive=NOW - ACTIVE_WINDOW + 60), "MERGED", (False, "active in the last 24 hours")),
        (wt(unpushed=["abc1234"]), "MERGED", (False, "1 commit(s) of yours exist only here")),
    ],
)
def test_worktree_decision(worktree, pr_state, expected):
    assert worktree_decision(worktree, pr_state, NOW) == expected


@pytest.mark.parametrize(
    ("name", "pr_state", "expected"),
    [
        ("pr-490-review", "MERGED", (True, "PR merged")),
        ("pr-490-review", "CLOSED", (True, "PR closed")),
        ("pr-490-review", "OPEN", (False, "open PR")),
        ("pr-490-review", None, (False, "PR not found")),
        ("release-0-8-helm", None, (False, "not a PR review cluster")),
    ],
)
def test_cluster_decision(name, pr_state, expected):
    assert cluster_decision(name, pr_state) == expected
