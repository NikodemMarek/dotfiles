import io
import json

import pytest

from knowledge import cli
from knowledge.decisions import Decision, Decisions
from knowledge.inbox import Inbox
from knowledge.records import from_event

SID = "s-20261006T153201Z-a1b2c3"


def status(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], *argv: str) -> tuple[int, str]:
    monkeypatch.setattr("sys.argv", ["knowledge", "status", *argv])
    monkeypatch.setattr("sys.stdin", io.StringIO(""))
    code = 0
    try:
        cli.main()
    except SystemExit as e:
        code = int(e.code or 0)
    return code, capsys.readouterr().out


def test_status_unknown(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    code, out = status(monkeypatch, capsys, SID)
    assert code == 0
    assert json.loads(out) == {"id": SID, "state": "unknown"}


def test_status_pending(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    Inbox().put(from_event({"id": SID, "title": "t", "body": "b", "origin": {"via": "cli"}}, via_router=True))
    code, out = status(monkeypatch, capsys, SID)
    assert code == 0
    assert json.loads(out) == {"id": SID, "state": "pending"}


def test_status_of_a_decision(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    Decisions().append(
        Decision(
            id=SID, key=SID, run="r-1", at="2026-10-06T16:00:00Z", verdict="create", reason="new",
            paths=("topic/jj/absorb.md",), commit="abc123", outcome="applied", notes=(),
        )  # fmt: skip
    )
    code, out = status(monkeypatch, capsys, SID)
    assert code == 0
    got = json.loads(out)
    assert (got["id"], got["state"], got["verdict"], got["paths"], got["commit"]) == (
        SID, "applied", "create", ["topic/jj/absorb.md"], "abc123",
    )  # fmt: skip
    assert out.count("\n") == 1  # one JSON line


def test_status_needs_an_id(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]):
    assert status(monkeypatch, capsys) == (2, "")
